# RuuviCloud

Cloud API interfaces and implementations used by Ruuvi Station.

## Email verification API migration

Email verification now requires both the sign-in code and the email address used
to request it. This is a source-breaking change from `validateCode(code:)` to
`validateCode(code:email:)`.

Callers must retain the email address entered when requesting a code and pass it
to verification. Implementations of `RuuviCloud`, including proxies and test
doubles, must adopt the new signature and forward both values. The code-only API
has no compatibility overload because the server requires the email address.
