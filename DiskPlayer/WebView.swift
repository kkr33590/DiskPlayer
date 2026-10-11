import SwiftUI
import WebKit

private let sniffer = """
(function(){
  var exts=/\\.(mp4|m4v|mov|m3u8|mpd|webm|mkv|mp3|m4a)(\\?|#|$)/i;
  var seen={};
  function report(u){
    try{
      if(!u||u.indexOf('blob:')===0||u.indexOf('data:')===0) return;
      var a=new URL(u,location.href).href;
      if(exts.test(a)&&!seen[a]){seen[a]=1;window.webkit.messageHandlers.media.postMessage(a);}
    }catch(e){}
  }
  var of=window.fetch;
  if(of){window.fetch=function(i){try{report(typeof i==='string'?i:i.url)}catch(e){}return of.apply(this,arguments)}}
  var oo=XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open=function(m,u){report(u);return oo.apply(this,arguments)};
  function scan(){
    document.querySelectorAll('video,source').forEach(function(v){report(v.currentSrc||v.src||v.getAttribute('src'))});
    try{performance.getEntriesByType('resource').forEach(function(e){report(e.name)})}catch(e){}
  }
  setInterval(scan,1200);
})();
"""

struct WebView: UIViewRepresentable {
    let url: URL
    var onMediaFound: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onMediaFound) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let script = WKUserScript(source: sniffer,
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        config.userContentController.add(context.coordinator, name: "media")
        let web = WKWebView(frame: .zero, configuration: config)
        web.allowsBackForwardNavigationGestures = true
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.onMediaFound = onMediaFound
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        var onMediaFound: (URL) -> Void
        init(_ cb: @escaping (URL) -> Void) { onMediaFound = cb }

        func userContentController(_ c: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            if let s = message.body as? String, let u = URL(string: s) {
                DispatchQueue.main.async { self.onMediaFound(u) }
            }
        }
    }
}
