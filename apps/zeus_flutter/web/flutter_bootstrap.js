{{flutter_js}}
{{flutter_build_config}}

const releaseBuild = _flutter.buildConfig.builds.some(
  (build) => build.compileTarget === 'dart2js',
);
if (releaseBuild && 'serviceWorker' in navigator) {
  navigator.serviceWorker.register('zeus_offline.js').catch((error) => {
    console.warn('Zeus Chat offline cache could not start.', error);
  });
}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href,
  },
});
