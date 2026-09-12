import AppKit
import WebKit

/// Native verification of the same NSViewRepresentable used on screen, opt-in launch argument only.
@MainActor enum ContentReviewVerification {
    static weak var webView: WKWebView?
    static func settle() async { try? await Task.sleep(for:.milliseconds(650)) }
    static func probe() async throws -> [String:Any] {
        guard let webView else { throw NSError(domain:"content-review",code:1) }
        let js = """
        (()=>{const r=document.getElementById('answer');return {
          inlineMathCount:r.querySelectorAll('.math-inline:not(.math-degraded)').length,
          displayMathCount:r.querySelectorAll('.math-display:not(.math-degraded)').length,
          degradedFormulaCount:r.querySelectorAll('.math-degraded').length,
          topItems:r.querySelectorAll(':scope > ol > li').length,
          subItems:r.querySelectorAll(':scope > ol > li:nth-child(3) > ul > li').length,
          tables:r.querySelectorAll('table').length,code:r.querySelectorAll('pre').length,
          overflow:r.scrollWidth>r.clientWidth+2,html:r.innerHTML,text:r.innerText,
          imageCount:r.querySelectorAll('img').length,
          loadedImages:[...r.querySelectorAll('img')].filter(x=>x.complete&&x.naturalWidth>0).length
          ,contentHeight:r.getBoundingClientRect().height,viewportHeight:innerHeight
        }})()
        """
        var value = try await webView.evaluateJavaScript(js) as? [String:Any] ?? [:]
        value["nativeHeight"] = Double(webView.frame.height)
        return value
    }
    static func capture(_ name:String) {
        guard let view = NSApp.windows.first(where:{$0.isVisible && $0.title.contains("History")})?.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) else { return }
        view.cacheDisplay(in:view.bounds,to:bitmap)
        try? bitmap.representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:"/private/tmp/fovea-reading-native-01a08bc5/rendered-history/" + name + ".png"))
    }
    static func run() async {
        let review = ContentReviewState.shared
        var results: [[String:Any]] = []
        do {
            for width in [560.0,360.0] {
                review.width = width
                for index in review.samples.indices {
                    review.select(index); await settle()
                    let sample = review.samples[index], value = try await probe()
                    var failures: [String] = []
                    for (key,expected) in sample.expected where ["inlineMathCount","displayMathCount","degradedFormulaCount"].contains(key) {
                        if value[key] as? Int != expected { failures.append(key) }
                    }
                    if value["overflow"] as? Bool != false { failures.append("page overflow") }
                    if (value["text"] as? String ?? "").isEmpty && value["loadedImages"] as? Int == 0 { failures.append("empty content") }
                    if (value["nativeHeight"] as? Double ?? 0) + 2 < (value["contentHeight"] as? Double ?? 0) { failures.append("native height clips content") }
                    if sample.id == "golden" && (value["topItems"] as? Int != 4 || value["subItems"] as? Int != 2) { failures.append("list structure") }
                    results.append(["id":sample.id,"width":width,"failures":failures,"nativeHeight":value["nativeHeight"] ?? 0,"contentHeight":value["contentHeight"] ?? 0])
                    if sample.id == "golden" { capture(width == 560 ? "B-content-golden" : "B-content-narrow") }
                    if sample.id == "F10" && width == 560 { capture("B-content-table-quote") }
                }
            }
            review.width = 560; review.select(0); await settle()
            let complete = try await probe()
            for fraction in [0.0,0.13,0.37,0.72,1.0] {
                review.fraction = fraction; await settle()
                let value = try await probe()
                results.append(["streamPrefix":fraction,"characters":(value["text"] as? String ?? "").count])
            }
            let replayed = try await probe()
            results.append(["streamConverges":complete["html"] as? String == replayed["html"] as? String])
            if let index = review.samples.firstIndex(where:{$0.id == "F14"}) {
                review.select(index); review.fraction = 0.8; await settle()
                review.interrupted = true; await settle(); let value = try await probe()
                results.append(["interruptedReadable":!(value["text"] as? String ?? "").isEmpty])
            }
            // Real recorded image, presented as an image format case; no invented answer or live event.
            if let index = review.samples.firstIndex(where:{$0.id == "recorded-image-format"}) {
                review.select(index); await settle(); let value = try await probe()
                results.append(["recordedImageLoaded":value["loadedImages"] as? Int == 1]);capture("B-content-image")
            }
            review.select(0); await settle()
        } catch { results.append(["error":String(describing:error)]) }
        if let data = try? JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]) {
            try? data.write(to:URL(fileURLWithPath:"/private/tmp/fovea-reading-native-01a08bc5/preview-data/content-native-results.json"))
        }
    }
}
