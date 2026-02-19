import Config

config :accessgrid,
  http_client: AccessGrid.HttpClient.Mock,
  # Route Req requests through Req.Test for the Req adapter integration tests
  # in test/access_grid/http_client/req_test.exs. The `AccessGrid.HttpClient.Req`
  # module reads this and injects `plug:` into its Req.new calls, so tests can
  # `Req.Test.stub(AccessGrid.HttpClient.Req, fn conn -> ... end)` without
  # needing a real HTTP server.
  req_plug: {Req.Test, AccessGrid.HttpClient.Req}
