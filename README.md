# Heimdall

The HTTP server and the actor system of Ymir, as a package built on midgard's primitives
(`std::net::tcp`, `std::concurrency`, `std::pack`) rather than shipped inside the standard library.

Work items live in the Plane project **HTTP server hardening** (`HTTPS`), workspace
`ymir-bootstrap`. HTTPS-1 tracks moving `std::net::http` and `std::concurrency::actor` out of
midgard into this repository.
