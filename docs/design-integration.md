# Liquid Glass integration

The app uses a local path dependency on the vendored `ui` package. The app
bundles the same fragment shader at the path expected by the original renderer.
The quality workflow compares the shader copies and runs the reference tests
against the local package.
