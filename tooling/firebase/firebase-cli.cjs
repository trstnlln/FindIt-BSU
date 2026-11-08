// Firebase CLI 15.35 unconditionally proxies even loopback requests. Respect
// local emulator routing while retaining its proxy and TLS checks for all
// external destinations. No installed package files or policies are changed.
const undici = require(require.resolve('undici', {paths: [require.resolve('firebase-tools/package.json')]}));
const ProxyAgent = undici.ProxyAgent;
class EmulatorAwareProxyAgent extends ProxyAgent {
  constructor(options) { super(options); this.localAgent = new undici.Agent(); }
  dispatch(options, handler) {
    const hostname = new URL(options.origin).hostname;
    if (['localhost','127.0.0.1','[::1]','::1'].includes(hostname)) return this.localAgent.dispatch(options,handler);
    return super.dispatch(options,handler);
  }
}
undici.ProxyAgent = EmulatorAwareProxyAgent;
require('firebase-tools/lib/bin/firebase.js');
