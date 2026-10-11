import SwiftUI
import WebKit

let mobileUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

private let sniffer = #"""
(function(){
  var exts=/\.(mp4|m4v|mov|m3u8|mpd|webm|mkv|mp3|m4a)(\?|#|$)/i;
  var seen={}, seenReq={};
  function abs(u){try{return new URL(u,location.href).href}catch(e){return null}}
  function post(t,u){try{window.webkit.messageHandlers.media.postMessage({t:t,u:u})}catch(e){}}
  function media(u,force){
    if(!u) return;
    if(u.indexOf('blob:')===0){ if(!seen[u]){seen[u]=1;post('b',u)} return; }
    if(u.indexOf('data:')===0) return;
    var a=abs(u); if(!a) return;
    if((force||exts.test(a))&&!seen[a]){seen[a]=1;post('m',a)}
  }
  function req(u){
    var a=abs(u);
    if(a&&a.indexOf('http')===0&&!seenReq[a]){seenReq[a]=1;post('r',a)}
  }
  var of=window.fetch;
  if(of){window.fetch=function(i){try{var u=(typeof i==='string')?i:i.url;req(u);media(u,false)}catch(e){}return of.apply(this,arguments)}}
  var oo=XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open=function(m,u){try{req(u);media(u,false)}catch(e){}return oo.apply(this,arguments)};
  function scan(){
    document.querySelectorAll('video,source').forEach(function(v){
      media(v.currentSrc||v.src||v.getAttribute('src'),true)
    });
    try{performance.getEntriesByType('resource').forEach(function(e){req(e.name);media(e.name,false)})}catch(e){}
  }
  setInterval(scan,1000);
})();
"""#

struct WebView: UIViewRepresentable {
    let url: URL
    let desktop: Bool
    var onEvent: (String, String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onEvent) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.preferredContentMode = desktop ? .desktop : .mobile
        let script = WKUserScript(source: sniffer,
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        config.userContentController.add(context.coordinator, name: "media")

        let web = WKWebView(frame: .zero, configuration: config)
        web.customUserAgent = desktop ? desktopUA : mobileUA
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.onEvent = onEvent
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        var onEvent: (String, String) -> Void
        init(_ cb: @escaping (String, String) -> Void) { onEvent = cb }

        func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let d = message.body as? [String: String],
                  let t = d["t"], let u = d["u"] else { return }
            DispatchQueue.main.async { self.onEvent(t, u) }
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let s = action.request.url?.scheme?.lowercased(), s == "http" || s == "https" || s == "about" {
                decisionHandler(.allow)
            } else {
                DispatchQueue.main.async { self.onEvent("r", "blocked scheme: \(action.request.url?.absoluteString ?? "")") }
                decisionHandler(.cancel)
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            DispatchQueue.main.async { self.onEvent("r", "popup ignored: \(action.request.url?.absoluteString ?? "")") }
            return nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.onEvent("r", "page loaded: \(webView.url?.absoluteString ?? "")") }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.onEvent("e", error.localizedDescription) }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.onEvent("e", error.localizedDescription) }
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            completionHandler()
        }
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            completionHandler(true)
        }
    }
}
