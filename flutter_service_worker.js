'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"version.json": "f093e93adac158cee2c7f3ea4fd9bd84",
"icons/Icon-192.png": "10635b6afbef8d3a2f08c64b7adfff04",
"icons/Icon-maskable-512.png": "b821c7e9947a9b585049744a2098da42",
"icons/Icon-maskable-192.png": "10635b6afbef8d3a2f08c64b7adfff04",
"icons/Icon-512.png": "b821c7e9947a9b585049744a2098da42",
"index.html": "bb5e69f89e25e733ddd89ae7c57b7c4a",
"/": "bb5e69f89e25e733ddd89ae7c57b7c4a",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/chromium/canvaskit.wasm": "c054c2c892172308ca5a0bd1d7a7754b",
"canvaskit/chromium/canvaskit.js.symbols": "f7c5e5502d577306fb6d530b1864ff86",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/skwasm.js.symbols": "9fe690d47b904d72c7d020bd303adf16",
"canvaskit/canvaskit.wasm": "a37f2b0af4995714de856e21e882325c",
"canvaskit/canvaskit.js.symbols": "27361387bc24144b46a745f1afe92b50",
"canvaskit/skwasm.wasm": "1c93738510f202d9ff44d36a4760126b",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"favicon.png": "f41fdb284687b20f2019b7ce2d4beb29",
"assets/AssetManifest.json": "99d69353ebe955ec0bf61240f7236bbf",
"assets/AssetManifest.bin.json": "b6bfcf7e0ca8a1298b818f4fcc68d1c6",
"assets/NOTICES": "a0fa881c9eff4b0222b68c1c43279e22",
"assets/fonts/MaterialIcons-Regular.otf": "0b1803108f01bf2f6af79ff871cd83e8",
"assets/FontManifest.json": "a9d8c31009846a8ff275ae855fe5e59e",
"assets/AssetManifest.bin": "c6836fe6d720b725826776bf16ddfa03",
"assets/assets/images/login_bg.webp": "7cf3a78fe34685d1c584f1c51ceb3403",
"assets/assets/images/logo.png": "0d6e10145c133b70acd992ed03b7eec5",
"assets/assets/images/logo_transparent.png": "e15652fbff89ac81763a7bd87d4ef5c3",
"assets/assets/lottie/school_register.json": "b40275815644b861fbd95af18c436ef5",
"assets/assets/lottie/admin.json": "199ba9aa413d0a35220712d51066ec5a",
"assets/assets/lottie/celebration.json": "76252e8f4c5a590836e033bb97f693ba",
"assets/assets/lottie/student_login.json": "31e39268b373122ab181569297d2f77b",
"assets/assets/lottie/success2.json": "30851337e4b0d54a9651007a8c01abe2",
"assets/assets/lottie/parent.json": "4131d055a781b92211f7d9f5c660e1bb",
"assets/assets/lottie/login_hero.json": "0428daf2eb7420d6c061fe4971a82915",
"assets/assets/lottie/student.json": "131e9b31852a62809dccdf7323e18eb0",
"assets/assets/lottie/surveillance.json": "f79d277bb6c10a8eddb3e31d4fb725e8",
"assets/assets/lottie/qr_scan.json": "43f4c778643c8788245c38f6d2c017ef",
"assets/assets/lottie/school_building.json": "3efb282c1c78f929389be51c20b7a142",
"assets/assets/lottie/success.json": "c127200663b376712a56c01848ab2d0e",
"assets/assets/lottie/teacher.json": "d67c316fd684a90d56b01c18a833598a",
"assets/assets/lottie/finance.json": "f321e223cdd6cbf43c3ff7cbd05d8dcd",
"assets/assets/lottie/loading.json": "17d858cd07815b7ba731a92c6dd125fa",
"assets/assets/translations/fr.json": "546957b88f50300eb4f1300955f8f656",
"assets/assets/translations/en.json": "fcdc09ee40a3d54feac5a6fe0e4a1dbf",
"assets/assets/translations/sw.json": "4166dd3e84a41001e224c621b6c0f7f9",
"assets/assets/translations/ln.json": "4f23ee7781d25e834cc22da163de4d57",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/packages/syncfusion_flutter_datagrid/assets/font/UnsortIcon.ttf": "6d8ab59254a120b76bf53f167e809470",
"assets/packages/syncfusion_flutter_datagrid/assets/font/FilterIcon.ttf": "c17d858d09fb1c596ef0adbf08872086",
"assets/packages/forui_assets/assets/lucide.ttf": "9a8778bf67d8bd6b058ada3e177a8cca",
"assets/packages/forui/assets/fonts/inter/Inter-ExtraLight.ttf": "7a177fa21fece72dfaa5639d8f1c114a",
"assets/packages/forui/assets/fonts/inter/Inter-Black.ttf": "118c5868c7cc1370fcf5a1fc2f569883",
"assets/packages/forui/assets/fonts/inter/Inter-Medium.ttf": "cad1054327a25f42f2447d1829596bfe",
"assets/packages/forui/assets/fonts/inter/Inter-SemiBold.ttf": "465266b2b986e33ef7e395f4df87b300",
"assets/packages/forui/assets/fonts/inter/Inter-Light.ttf": "a3fe4e0f9fdf3119c62a34b1937640dd",
"assets/packages/forui/assets/fonts/inter/Inter-Thin.ttf": "4558ff85abeab91af24c86aab81509a7",
"assets/packages/forui/assets/fonts/inter/Inter-Bold.ttf": "ba74cc325d5f67d0efbeda51616352db",
"assets/packages/forui/assets/fonts/inter/Inter-Regular.ttf": "ea5879884a95551632e9eb1bba5b2128",
"assets/packages/forui/assets/fonts/inter/Inter-ExtraBold.ttf": "72ac147c98056996b2a31e95a56d6e66",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "825e75415ebd366b740bb49659d7a5c6",
"main.dart.js": "be8839ebfeea41ce187e5320751ebc3e",
"404.html": "38ceafe53f7af79bd4facb0274c1babc",
"flutter_bootstrap.js": "28535712eb894055d745641fdd8fdb11",
"manifest.json": "f4e4656ca558cd447ab5054c23cfacb4"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
