# Architecture

`apps/zeus_flutter` owns app routes and the localized user interface.
`packages/zeus_glass` owns the original design engine and its platform fallback.
The application renders content beneath one shared capture host and loads the
fragment program from its own bundle.

The product uses local storage for chat and preferences and platform key storage
for provider secrets. Provider adapters translate native network responses into
ordered chat events before they enter the chat UI. The optional Zeus Hub is a
separate service for authenticated sync and persistent jobs.
