import Config

config :accessgrid,
  api_host: "https://api.accessgrid.com",
  http_client: AccessGrid.HttpClient.Req

import_config "#{config_env()}.exs"
