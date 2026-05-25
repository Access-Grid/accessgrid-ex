defmodule AccessGrid.ConsoleTest do
  use ExUnit.Case, async: true
  use Test.HttpClientMocking

  alias AccessGrid.CardTemplate
  alias AccessGrid.CardTemplatePair
  alias AccessGrid.Client
  alias AccessGrid.Console
  alias AccessGrid.CredentialProfile
  alias AccessGrid.Event
  alias AccessGrid.HidOrg
  alias AccessGrid.IosPreflight
  alias AccessGrid.LandingPage
  alias AccessGrid.LedgerItem
  alias AccessGrid.SmartTapReveal
  alias AccessGrid.Webhook

  @client Client.new(
            account_id: "acct_123",
            api_secret: "test_secret",
            api_host: "https://api.accessgrid.com"
          )

  describe "create_template/2" do
    test "returns {:ok, CardTemplate.Result} on success" do
      response_body = %{
        "id" => "tpl_abc123",
        "estimated_publishing_date" => "2026-02-02T12:00:00Z",
        "metadata" => %{"version" => "1.0"}
      }

      expect(mock_http_client(), :post, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/console/card-templates"
        assert opts[:body][:name] == "Test Template"
        assert opts[:body][:platform] == "apple"
        {:ok, %HttpResponse{status: 201, body_decoded: response_body}}
      end)

      assert {:ok, %CardTemplate.Result{} = result} =
               Console.create_template(
                 %{
                   name: "Test Template",
                   platform: "apple",
                   use_case: "corporate_id",
                   protocol: "desfire"
                 },
                 client: @client
               )

      assert result.id == "tpl_abc123"
      assert result.estimated_publishing_date == "2026-02-02T12:00:00Z"
      assert result.metadata == %{"version" => "1.0"}
    end

    test "passes design and support params flat at top level" do
      # The SDK no longer flattens nested `design:` / `support_info:` maps —
      # callers pass design/support keys at the top level using the Rails wire
      # names exactly. Locks in that the SDK is a 1:1 passthrough.
      expect(mock_http_client(), :post, fn _url, opts ->
        assert opts[:body][:background_color] == "#FFFFFF"
        assert opts[:body][:label_color] == "#000000"
        assert opts[:body][:support_url] == "https://help.example.com"
        assert opts[:body][:support_email] == "help@example.com"
        {:ok, %HttpResponse{status: 201, body_decoded: %{"id" => "tpl_123"}}}
      end)

      Console.create_template(
        %{
          name: "Test",
          platform: "apple",
          use_case: "corporate_id",
          protocol: "desfire",
          background_color: "#FFFFFF",
          label_color: "#000000",
          support_url: "https://help.example.com",
          support_email: "help@example.com"
        },
        client: @client
      )
    end

    test "passes credential_profiles and landing_pages arrays through unchanged" do
      # Rails accepts these as top-level arrays of ex_id strings on create
      # (resolved pre-strong-params in enterprise_controller). The SDK is a
      # pure passthrough — no transform, no per-key handling.
      expect(mock_http_client(), :post, fn _url, opts ->
        assert opts[:body][:credential_profiles] == ["cp_ex1", "cp_ex2"]
        assert opts[:body][:landing_pages] == ["lp_ex1"]
        {:ok, %HttpResponse{status: 201, body_decoded: %{"id" => "tpl_123"}}}
      end)

      Console.create_template(
        %{
          name: "Test",
          platform: "apple",
          use_case: "corporate_id",
          protocol: "desfire",
          credential_profiles: ["cp_ex1", "cp_ex2"],
          landing_pages: ["lp_ex1"]
        },
        client: @client
      )
    end

    test "passes image params (background, logo, icon) at top level unchanged" do
      # Rails reads params[:background], params[:logo], params[:icon] —
      # NOT params[:background_image] etc. Callers pass base64 strings at the
      # top level using these wire-key names. Regression test for the bug
      # where the SDK previously mapped `:background_image` → wire `:background_image`,
      # which Rails silently ignored.
      expect(mock_http_client(), :post, fn _url, opts ->
        assert opts[:body][:background] == "<base64-background>"
        assert opts[:body][:logo] == "<base64-logo>"
        assert opts[:body][:icon] == "<base64-icon>"
        {:ok, %HttpResponse{status: 201, body_decoded: %{"id" => "tpl_123"}}}
      end)

      Console.create_template(
        %{
          name: "Test",
          platform: "apple",
          use_case: "corporate_id",
          protocol: "desfire",
          background: "<base64-background>",
          logo: "<base64-logo>",
          icon: "<base64-icon>"
        },
        client: @client
      )
    end

    test "returns {:error, :validation_failed, failure} on 422" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error, %HttpFailure{status: 422, reason: :unprocessable_entity, body_decoded: %{"message" => "Invalid"}}}
      end)

      assert {:error, :validation_failed, %HttpFailure{}} =
               Console.create_template(
                 %{name: "Bad", platform: "apple", use_case: "corporate_id", protocol: "desfire"},
                 client: @client
               )
    end

    test "returns {:error, :unauthorized, failure} on 401" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error, %HttpFailure{status: 401, reason: :unauthorized}}
      end)

      assert {:error, :unauthorized, %HttpFailure{}} =
               Console.create_template(
                 %{name: "Test", platform: "apple", use_case: "corporate_id", protocol: "desfire"},
                 client: @client
               )
    end

    test "returns {:error, :missing_required, [keys]} when required fields are missing" do
      # Local validation short-circuits before HTTP — no mock needed.
      assert {:error, :missing_required, [:protocol]} =
               Console.create_template(
                 %{name: "X", platform: "apple", use_case: "corporate_id"},
                 client: @client
               )

      # All four missing at once → list of all four (input order preserved)
      assert {:error, :missing_required, [:name, :platform, :use_case, :protocol]} =
               Console.create_template(%{}, client: @client)
    end
  end

  describe "update_template/3" do
    test "returns {:ok, CardTemplate.Result} on success" do
      response_body = %{
        "id" => "tpl_abc123",
        "estimated_publishing_date" => "2026-02-03T12:00:00Z",
        "metadata" => %{}
      }

      expect(mock_http_client(), :put, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/console/card-templates/tpl_abc123"
        assert opts[:body][:name] == "Updated Name"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %CardTemplate.Result{} = result} =
               Console.update_template("tpl_abc123", %{name: "Updated Name"}, client: @client)

      assert result.id == "tpl_abc123"
    end

    test "returns {:error, :not_found, failure} on 404" do
      expect(mock_http_client(), :put, fn _url, _opts ->
        {:error, %HttpFailure{status: 404, reason: :not_found}}
      end)

      assert {:error, :not_found, %HttpFailure{}} =
               Console.update_template("tpl_invalid", %{name: "Test"}, client: @client)
    end
  end

  describe "read_template/2" do
    test "returns {:ok, CardTemplate} with full data on success" do
      # Rails groups some fields under nested objects on the wire
      # (allowed_device_counts, support_settings, terms_settings, style_settings)
      # and renames a few keys (e.g. support_settings.url is wire-name for what
      # the SDK exposes as :support_url). CardTemplate.from_response/1 does
      # the flatten + rename so the struct fields match the request param names.
      response_body = %{
        "id" => "tpl_abc123",
        "name" => "Corporate Badge",
        "platform" => "apple",
        "protocol" => "desfire",
        "use_case" => "corporate_id",
        "created_at" => "2026-01-15T10:00:00Z",
        "last_published_at" => "2026-01-20T14:00:00Z",
        "issued_keys_count" => 150,
        "active_keys_count" => 142,
        "allowed_device_counts" => %{
          "allow_on_multiple_devices" => true,
          "watch" => 2,
          "iphone" => 3
        },
        "support_settings" => %{
          "url" => "https://help.example.com",
          "phone" => "+1-555-1234",
          "email" => "help@example.com"
        },
        "terms_settings" => %{
          "privacy_policy_url" => "https://example.com/privacy",
          "terms_and_conditions_url" => "https://example.com/terms"
        },
        "style_settings" => %{
          "background_color" => "#FFFFFF",
          "label_color" => "#000000",
          "label_secondary_color" => "#333333"
        },
        "credential_profiles" => ["cp_ex1", "cp_ex2"],
        "landing_pages" => ["lp_ex1"],
        "metadata" => %{"version" => "2.0"}
      }

      expect(mock_http_client(), :get, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/console/card-templates/tpl_abc123"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %CardTemplate{} = template} = Console.read_template("tpl_abc123", client: @client)

      assert template.id == "tpl_abc123"
      assert template.name == "Corporate Badge"
      assert template.platform == "apple"
      assert template.protocol == "desfire"
      assert template.use_case == "corporate_id"
      assert template.issued_keys_count == 150
      assert template.active_keys_count == 142

      # Flattened from allowed_device_counts
      assert template.allow_on_multiple_devices == true
      assert template.watch_count == 2
      assert template.iphone_count == 3

      # Flattened + renamed from support_settings
      assert template.support_url == "https://help.example.com"
      assert template.support_phone_number == "+1-555-1234"
      assert template.support_email == "help@example.com"

      # Flattened from terms_settings
      assert template.privacy_policy_url == "https://example.com/privacy"
      assert template.terms_and_conditions_url == "https://example.com/terms"

      # Flattened from style_settings
      assert template.background_color == "#FFFFFF"
      assert template.label_color == "#000000"
      assert template.label_secondary_color == "#333333"

      # Universal-gap fields (PHP + Elixir)
      assert template.credential_profiles == ["cp_ex1", "cp_ex2"]
      assert template.landing_pages == ["lp_ex1"]

      assert template.metadata == %{"version" => "2.0"}
    end

    test "returns {:error, :not_found, failure} on 404" do
      expect(mock_http_client(), :get, fn _url, _opts ->
        {:error, %HttpFailure{status: 404, reason: :not_found}}
      end)

      assert {:error, :not_found, %HttpFailure{}} =
               Console.read_template("tpl_invalid", client: @client)
    end

    test "returns {:ok, TemplatePair} when the id resolves to a pair" do
      response_body = %{
        "id" => "pair_abc",
        "is_pair" => true,
        "name" => "Cross-Platform Badge",
        "templates" => [
          %{
            "id" => "tpl_apple",
            "name" => "Apple Side",
            "platform" => "apple",
            "protocol" => "desfire",
            "use_case" => "corporate_id",
            "issued_keys_count" => 44,
            "active_keys_count" => 42,
            "metadata" => %{"variant" => "v1"}
          },
          %{
            "id" => "tpl_android",
            "name" => "Android Side",
            "platform" => "android",
            "protocol" => "smart_tap",
            "use_case" => "corporate_id",
            "issued_keys_count" => 0,
            "active_keys_count" => 0,
            "metadata" => %{}
          }
        ]
      }

      expect(mock_http_client(), :get, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/console/card-templates/pair_abc"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %CardTemplatePair{} = pair} = Console.read_template("pair_abc", client: @client)

      assert pair.id == "pair_abc"
      assert pair.name == "Cross-Platform Badge"

      assert [%CardTemplate{} = apple, %CardTemplate{} = android] = pair.templates
      assert apple.id == "tpl_apple"
      assert apple.platform == "apple"
      assert apple.protocol == "desfire"
      assert apple.issued_keys_count == 44
      assert apple.metadata == %{"variant" => "v1"}

      assert android.id == "tpl_android"
      assert android.platform == "android"
      assert android.protocol == "smart_tap"
    end
  end

  describe "get_logs/2" do
    test "returns {:ok, events, pagination} on success" do
      response_body = %{
        "logs" => [
          %{
            "id" => 1,
            "event" => "access_pass.device_added",
            "created_at" => "2026-01-20T14:30:00Z",
            "ip_address" => "192.168.1.1",
            "user_agent" => "iPhone/16.0",
            "metadata" => %{"device" => "mobile"}
          },
          %{
            "id" => 2,
            "event" => "access_pass.installed",
            "created_at" => "2026-01-20T14:31:00Z",
            "ip_address" => "192.168.1.1",
            "user_agent" => "iPhone/16.0",
            "metadata" => %{}
          }
        ],
        "pagination" => %{
          "current_page" => 1,
          "per_page" => 50,
          "total_pages" => 1,
          "total_count" => 2
        }
      }

      expect(mock_http_client(), :get, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/console/card-templates/tpl_123/logs"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, events, pagination} = Console.get_logs("tpl_123", client: @client)

      assert length(events) == 2
      assert [%Event{} = event1, %Event{} = event2] = events
      assert event1.id == 1
      assert event1.event == "access_pass.device_added"
      assert event1.ip_address == "192.168.1.1"
      assert event2.id == 2

      assert pagination["current_page"] == 1
      assert pagination["total_count"] == 2
    end

    test "passes pagination params" do
      expect(mock_http_client(), :get, fn _url, opts ->
        assert opts[:params][:page] == 2
        assert opts[:params][:per_page] == 25
        {:ok, %HttpResponse{status: 200, body_decoded: %{"logs" => [], "pagination" => %{}}}}
      end)

      Console.get_logs("tpl_123", client: @client, page: 2, per_page: 25)
    end

    test "passes filter params" do
      expect(mock_http_client(), :get, fn _url, opts ->
        assert opts[:params][:filters][:device] == "mobile"
        assert opts[:params][:filters][:event_type] == "access_pass.installed"
        {:ok, %HttpResponse{status: 200, body_decoded: %{"logs" => [], "pagination" => %{}}}}
      end)

      Console.get_logs("tpl_123",
        client: @client,
        filters: %{device: "mobile", event_type: "access_pass.installed"}
      )
    end
  end

  describe "list_card_template_pairs/1" do
    test "returns {:ok, pairs, pagination} on success" do
      response_body = %{
        "card_template_pairs" => [
          %{
            "id" => "pair_123",
            "name" => "Cross-Platform Badge",
            "created_at" => "2026-01-10T09:00:00Z",
            "android_template" => %{
              "id" => "tpl_android_1",
              "name" => "Android Badge",
              "platform" => "google"
            },
            "ios_template" => %{
              "id" => "tpl_ios_1",
              "name" => "iOS Badge",
              "platform" => "apple"
            }
          }
        ],
        "pagination" => %{
          "current_page" => 1,
          "per_page" => 50,
          "total_pages" => 1,
          "total_count" => 1
        }
      }

      expect(mock_http_client(), :get, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/console/card-template-pairs"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, pairs, pagination} = Console.list_card_template_pairs(client: @client)

      assert length(pairs) == 1
      assert [%CardTemplatePair.Summary{} = pair] = pairs
      assert pair.id == "pair_123"
      assert pair.name == "Cross-Platform Badge"

      assert %CardTemplate.Summary{} = pair.android_template
      assert pair.android_template.id == "tpl_android_1"
      assert pair.android_template.platform == "google"

      assert %CardTemplate.Summary{} = pair.ios_template
      assert pair.ios_template.id == "tpl_ios_1"
      assert pair.ios_template.platform == "apple"

      assert pagination["total_count"] == 1
    end

    test "handles pairs with nil templates" do
      response_body = %{
        "card_template_pairs" => [
          %{
            "id" => "pair_123",
            "name" => "iOS Only",
            "created_at" => "2026-01-10T09:00:00Z",
            "android_template" => nil,
            "ios_template" => %{
              "id" => "tpl_ios_1",
              "name" => "iOS Badge",
              "platform" => "apple"
            }
          }
        ],
        "pagination" => %{}
      }

      expect(mock_http_client(), :get, fn _url, _opts ->
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, [pair], _pagination} = Console.list_card_template_pairs(client: @client)
      assert pair.android_template == nil
      assert pair.ios_template != nil
    end

    test "passes pagination params" do
      expect(mock_http_client(), :get, fn _url, opts ->
        assert opts[:params][:page] == 3
        assert opts[:params][:per_page] == 10
        {:ok, %HttpResponse{status: 200, body_decoded: %{"card_template_pairs" => [], "pagination" => %{}}}}
      end)

      Console.list_card_template_pairs(client: @client, page: 3, per_page: 10)
    end
  end

  describe "create_card_template_pair/2" do
    test "returns {:ok, CardTemplatePair.Summary} on 201" do
      response_body = %{
        "id" => "pair_new123",
        "ex_id" => "pair_new123",
        "name" => "Cross-Platform Badge",
        "created_at" => "2026-05-16T12:00:00Z",
        "android_template" => %{
          "id" => "tpl_android_42",
          "ex_id" => "tpl_android_42",
          "name" => "Android Badge",
          "platform" => "android"
        },
        "ios_template" => %{
          "id" => "tpl_ios_42",
          "ex_id" => "tpl_ios_42",
          "name" => "iOS Badge",
          "platform" => "apple"
        }
      }

      expect(mock_http_client(), :post, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/console/card-template-pairs"
        assert opts[:body][:name] == "Cross-Platform Badge"
        assert opts[:body][:apple_card_template_id] == "tpl_ios_42"
        assert opts[:body][:google_card_template_id] == "tpl_android_42"
        {:ok, %HttpResponse{status: 201, body_decoded: response_body}}
      end)

      assert {:ok, %CardTemplatePair.Summary{} = pair} =
               Console.create_card_template_pair(
                 %{
                   name: "Cross-Platform Badge",
                   apple_card_template_id: "tpl_ios_42",
                   google_card_template_id: "tpl_android_42"
                 },
                 client: @client
               )

      assert pair.id == "pair_new123"
      assert pair.name == "Cross-Platform Badge"
      assert pair.created_at == "2026-05-16T12:00:00Z"

      assert %CardTemplate.Summary{} = pair.android_template
      assert pair.android_template.id == "tpl_android_42"
      assert pair.android_template.platform == "android"

      assert %CardTemplate.Summary{} = pair.ios_template
      assert pair.ios_template.id == "tpl_ios_42"
      assert pair.ios_template.platform == "apple"
    end

    test "returns {:error, :not_found, failure} on 404" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error,
         %HttpFailure{status: 404, reason: :not_found, body_decoded: %{"message" => "Apple card template not found"}}}
      end)

      assert {:error, :not_found, %HttpFailure{}} =
               Console.create_card_template_pair(
                 %{name: "X", apple_card_template_id: "missing", google_card_template_id: "tpl_2"},
                 client: @client
               )
    end

    test "returns {:error, :validation_failed, failure} on 422" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 422,
           reason: :unprocessable_entity,
           body_decoded: %{"message" => "Protocol combination not supported"}
         }}
      end)

      assert {:error, :validation_failed, %HttpFailure{}} =
               Console.create_card_template_pair(
                 %{name: "X", apple_card_template_id: "tpl_1", google_card_template_id: "tpl_2"},
                 client: @client
               )
    end
  end

  describe "ios_preflight/3" do
    test "returns {:ok, IosPreflight} on 200" do
      response_body = %{
        "provisioningCredentialIdentifier" => "apple_ap_abc123",
        "sharingInstanceIdentifier" => "share_xyz789",
        "cardTemplateIdentifier" => "apple_tpl_42",
        "environmentIdentifier" => "prod"
      }

      expect(mock_http_client(), :post, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/console/card-templates/tpl_123/ios_preflight"
        assert opts[:body][:access_pass_ex_id] == "ap_456"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %IosPreflight{} = result} =
               Console.ios_preflight("tpl_123", %{access_pass_ex_id: "ap_456"}, client: @client)

      assert result.provisioning_credential_identifier == "apple_ap_abc123"
      assert result.sharing_instance_identifier == "share_xyz789"
      assert result.card_template_identifier == "apple_tpl_42"
      assert result.environment_identifier == "prod"
    end

    test "returns {:error, :not_found, failure} on 404" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error, %HttpFailure{status: 404, reason: :not_found, body_decoded: %{"error" => "AccessPass not found"}}}
      end)

      assert {:error, :not_found, %HttpFailure{}} =
               Console.ios_preflight("tpl_123", %{access_pass_ex_id: "missing"}, client: @client)
    end
  end

  describe "list_landing_pages/1" do
    test "returns {:ok, pages} on success" do
      response_body = [
        %{
          "id" => "lp_abc123",
          "name" => "Lobby Access",
          "created_at" => "2026-05-01T10:00:00Z",
          "kind" => "standard",
          "password_protected" => false,
          "logo_url" => "https://cdn.example.com/lobby.png"
        },
        %{
          "id" => "lp_def456",
          "name" => "VIP",
          "created_at" => "2026-05-02T10:00:00Z",
          "kind" => "premium",
          "password_protected" => true,
          "logo_url" => nil
        }
      ]

      expect(mock_http_client(), :get, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/console/landing-pages"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, pages} = Console.list_landing_pages(client: @client)
      assert [%LandingPage{} = first, %LandingPage{} = second] = pages
      assert first.id == "lp_abc123"
      assert first.name == "Lobby Access"
      assert first.kind == "standard"
      assert first.password_protected == false
      assert first.logo_url == "https://cdn.example.com/lobby.png"
      assert second.password_protected == true
      assert second.logo_url == nil
    end

    test "returns {:ok, []} when there are no landing pages" do
      expect(mock_http_client(), :get, fn _url, _opts ->
        {:ok, %HttpResponse{status: 200, body_decoded: []}}
      end)

      assert {:ok, []} = Console.list_landing_pages(client: @client)
    end
  end

  describe "create_landing_page/2" do
    test "returns {:ok, LandingPage} on 201" do
      response_body = %{
        "id" => "lp_new789",
        "name" => "Test Page",
        "created_at" => "2026-05-17T12:00:00Z",
        "kind" => "standard",
        "password_protected" => false,
        "logo_url" => nil
      }

      expect(mock_http_client(), :post, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/console/landing-pages"
        assert opts[:body][:name] == "Test Page"
        assert opts[:body][:kind] == "standard"
        {:ok, %HttpResponse{status: 201, body_decoded: response_body}}
      end)

      assert {:ok, %LandingPage{} = page} =
               Console.create_landing_page(%{name: "Test Page", kind: "standard"}, client: @client)

      assert page.id == "lp_new789"
      assert page.kind == "standard"
    end

    test "returns {:error, :validation_failed, failure} on 422" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error,
         %HttpFailure{status: 422, reason: :unprocessable_entity, body_decoded: %{"message" => ["Name can't be blank"]}}}
      end)

      assert {:error, :validation_failed, %HttpFailure{}} =
               Console.create_landing_page(%{name: "X", kind: "standard"}, client: @client)
    end
  end

  describe "update_landing_page/3" do
    test "returns {:ok, LandingPage} on 200" do
      response_body = %{
        "id" => "lp_abc123",
        "name" => "Updated Name",
        "created_at" => "2026-05-01T10:00:00Z",
        "kind" => "standard",
        "password_protected" => true,
        "logo_url" => nil
      }

      expect(mock_http_client(), :put, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/console/landing-pages/lp_abc123"
        assert opts[:body][:name] == "Updated Name"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %LandingPage{} = page} =
               Console.update_landing_page(
                 "lp_abc123",
                 %{name: "Updated Name", password: "secret"},
                 client: @client
               )

      assert page.name == "Updated Name"
      assert page.password_protected == true
    end

    test "returns {:error, :not_found, failure} on 404" do
      expect(mock_http_client(), :put, fn _url, _opts ->
        {:error, %HttpFailure{status: 404, reason: :not_found, body_decoded: %{"message" => "Landing page not found"}}}
      end)

      assert {:error, :not_found, %HttpFailure{}} =
               Console.update_landing_page("lp_missing", %{name: "X"}, client: @client)
    end

    test "returns {:error, :validation_failed, failure} when kind is changed" do
      expect(mock_http_client(), :put, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 422,
           reason: :unprocessable_entity,
           body_decoded: %{"message" => ["Kind is immutable after creation"]}
         }}
      end)

      assert {:error, :validation_failed, %HttpFailure{}} =
               Console.update_landing_page("lp_abc123", %{kind: "premium"}, client: @client)
    end
  end

  describe "list_credential_profiles/1" do
    test "returns {:ok, profiles} on success" do
      response_body = [
        %{
          "id" => "cp_abc123",
          "aid" => "F0010203040506",
          "name" => "Office Reader",
          "apple_id" => nil,
          "created_at" => "2026-05-01T10:00:00Z",
          "card_storage" => "DESFire EV2 4K",
          "keys" => [
            %{
              "ex_id" => "00",
              "label" => "Auth Key",
              "keys_diversified" => false,
              "source_key_index" => nil
            }
          ],
          "files" => [
            %{
              "ex_id" => "00",
              "file_type" => "standard",
              "file_size" => 256,
              "communication_settings" => "encrypted_with_mac",
              "read_rights" => "read",
              "write_rights" => "master",
              "read_write_rights" => "master",
              "change_rights" => "no-keys"
            }
          ]
        }
      ]

      expect(mock_http_client(), :get, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/console/credential-profiles"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, profiles} = Console.list_credential_profiles(client: @client)
      assert [%CredentialProfile{} = first] = profiles
      assert first.id == "cp_abc123"
      assert first.aid == "F0010203040506"
      assert first.name == "Office Reader"
      assert first.apple_id == nil
      assert first.card_storage == "DESFire EV2 4K"

      assert [key] = first.keys
      assert key["label"] == "Auth Key"
      assert key["keys_diversified"] == false

      assert [file] = first.files
      assert file["file_type"] == "standard"
      assert file["file_size"] == 256
    end

    test "returns {:ok, []} when there are no credential profiles" do
      expect(mock_http_client(), :get, fn _url, _opts ->
        {:ok, %HttpResponse{status: 200, body_decoded: []}}
      end)

      assert {:ok, []} = Console.list_credential_profiles(client: @client)
    end
  end

  describe "create_credential_profile/2" do
    test "returns {:ok, CredentialProfile} on 201" do
      response_body = %{
        "id" => "cp_new789",
        "aid" => "F0010203040506",
        "name" => "Test Profile",
        "apple_id" => nil,
        "created_at" => "2026-05-17T12:00:00Z",
        "card_storage" => "DESFire EV2 4K",
        "keys" => [
          %{
            "ex_id" => "00",
            "label" => "Auth Key",
            "keys_diversified" => false,
            "source_key_index" => nil
          }
        ],
        "files" => [
          %{
            "ex_id" => "00",
            "file_type" => "standard",
            "file_size" => 256,
            "communication_settings" => "encrypted_with_mac",
            "read_rights" => "read",
            "write_rights" => "master",
            "read_write_rights" => "master",
            "change_rights" => "no-keys"
          }
        ]
      }

      expect(mock_http_client(), :post, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/console/credential-profiles"
        assert opts[:body][:name] == "Test Profile"
        assert opts[:body][:app_name] == "KEY-ID-main"
        assert [key] = opts[:body][:keys]
        assert key[:value] == "ABCDEF0123456789ABCDEF0123456789"
        {:ok, %HttpResponse{status: 201, body_decoded: response_body}}
      end)

      assert {:ok, %CredentialProfile{} = profile} =
               Console.create_credential_profile(
                 %{
                   name: "Test Profile",
                   app_name: "KEY-ID-main",
                   keys: [%{value: "ABCDEF0123456789ABCDEF0123456789"}]
                 },
                 client: @client
               )

      assert profile.id == "cp_new789"
      assert profile.name == "Test Profile"
    end

    test "returns {:error, :validation_failed, failure} on invalid app_name" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 422,
           reason: :unprocessable_entity,
           body_decoded: %{"message" => ["Invalid app_name. Must be one of: KEY-ID-main"]}
         }}
      end)

      assert {:error, :validation_failed, %HttpFailure{}} =
               Console.create_credential_profile(
                 %{name: "X", app_name: "WRONG", keys: []},
                 client: @client
               )
    end

    test "returns {:error, :validation_failed, failure} on wrong key count" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 422,
           reason: :unprocessable_entity,
           body_decoded: %{"message" => ["Exactly 1 keys are required for KEY-ID-main"]}
         }}
      end)

      assert {:error, :validation_failed, %HttpFailure{}} =
               Console.create_credential_profile(
                 %{name: "X", keys: []},
                 client: @client
               )
    end
  end

  describe "list_webhooks/1" do
    test "returns {:ok, webhooks, pagination} on success" do
      response_body = %{
        "webhooks" => [
          %{
            "id" => "wh_abc123",
            "name" => "Production",
            "url" => "https://example.com/hooks",
            "auth_method" => "bearer_token",
            "subscribed_events" => ["ag.access_pass.issued", "ag.card_template.created"],
            "created_at" => "2026-05-01T10:00:00Z"
          },
          %{
            "id" => "wh_def456",
            "name" => "Secure",
            "url" => "https://example.com/mtls",
            "auth_method" => "mtls",
            "subscribed_events" => ["ag.access_pass.installed"],
            "created_at" => "2026-05-02T10:00:00Z",
            "cert_expires_at" => "2027-05-02T10:00:00Z"
          }
        ],
        "pagination" => %{
          "current_page" => 1,
          "per_page" => 50,
          "total_pages" => 1,
          "total_count" => 2
        }
      }

      expect(mock_http_client(), :get, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/console/webhooks"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, webhooks, pagination} = Console.list_webhooks(client: @client)
      assert [%Webhook{} = first, %Webhook{} = second] = webhooks
      assert first.id == "wh_abc123"
      assert first.auth_method == "bearer_token"
      assert first.subscribed_events == ["ag.access_pass.issued", "ag.card_template.created"]
      assert second.auth_method == "mtls"
      assert second.cert_expires_at == "2027-05-02T10:00:00Z"
      assert pagination["total_count"] == 2
    end

    test "passes pagination params" do
      expect(mock_http_client(), :get, fn _url, opts ->
        assert opts[:params][:page] == 2
        assert opts[:params][:per_page] == 10
        {:ok, %HttpResponse{status: 200, body_decoded: %{"webhooks" => [], "pagination" => %{}}}}
      end)

      Console.list_webhooks(client: @client, page: 2, per_page: 10)
    end
  end

  describe "create_webhook/2" do
    test "returns {:ok, Webhook} with private_key on bearer_token create" do
      response_body = %{
        "id" => "wh_new789",
        "name" => "Production",
        "url" => "https://example.com/hooks",
        "auth_method" => "bearer_token",
        "subscribed_events" => ["ag.access_pass.issued"],
        "created_at" => "2026-05-17T12:00:00Z",
        "private_key" => "whsec_secret_value_here"
      }

      expect(mock_http_client(), :post, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/console/webhooks"
        assert opts[:body][:name] == "Production"
        assert opts[:body][:auth_method] == "bearer_token"
        {:ok, %HttpResponse{status: 201, body_decoded: response_body}}
      end)

      assert {:ok, %Webhook{} = webhook} =
               Console.create_webhook(
                 %{
                   name: "Production",
                   url: "https://example.com/hooks",
                   subscribed_events: ["ag.access_pass.issued"],
                   auth_method: "bearer_token"
                 },
                 client: @client
               )

      assert webhook.id == "wh_new789"
      assert webhook.auth_method == "bearer_token"
      assert webhook.private_key == "whsec_secret_value_here"
      assert webhook.client_cert == nil
      assert webhook.cert_expires_at == nil
    end

    test "returns {:ok, Webhook} with client_cert and cert_expires_at on mtls create" do
      response_body = %{
        "id" => "wh_mtls_42",
        "name" => "Secure",
        "url" => "https://example.com/mtls",
        "auth_method" => "mtls",
        "subscribed_events" => ["ag.access_pass.installed"],
        "created_at" => "2026-05-17T12:00:00Z",
        "client_cert" => "-----BEGIN CERTIFICATE-----\nMIIB...\n-----END CERTIFICATE-----",
        "cert_expires_at" => "2027-05-17T12:00:00Z"
      }

      expect(mock_http_client(), :post, fn _url, opts ->
        assert opts[:body][:auth_method] == "mtls"
        {:ok, %HttpResponse{status: 201, body_decoded: response_body}}
      end)

      assert {:ok, %Webhook{} = webhook} =
               Console.create_webhook(
                 %{
                   name: "Secure",
                   url: "https://example.com/mtls",
                   subscribed_events: ["ag.access_pass.installed"],
                   auth_method: "mtls"
                 },
                 client: @client
               )

      assert webhook.auth_method == "mtls"
      assert webhook.client_cert =~ "BEGIN CERTIFICATE"
      assert webhook.cert_expires_at == "2027-05-17T12:00:00Z"
      assert webhook.private_key == nil
    end

    test "returns {:error, :validation_failed, failure} on invalid event name" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 422,
           reason: :unprocessable_entity,
           body_decoded: %{"message" => "Invalid event name: 'not.a.real.event'. Valid events are: ..."}
         }}
      end)

      assert {:error, :validation_failed, %HttpFailure{}} =
               Console.create_webhook(
                 %{
                   name: "X",
                   url: "https://example.com",
                   subscribed_events: ["not.a.real.event"],
                   auth_method: "bearer_token"
                 },
                 client: @client
               )
    end
  end

  describe "delete_webhook/2" do
    test "returns :ok on 204 No Content" do
      expect(mock_http_client(), :delete, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/console/webhooks/wh_abc123"
        {:ok, %HttpResponse{status: 204, body_decoded: nil}}
      end)

      assert :ok = Console.delete_webhook("wh_abc123", client: @client)
    end

    test "returns {:error, :not_found, failure} on 404" do
      expect(mock_http_client(), :delete, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 404,
           reason: :not_found,
           body_decoded: %{"message" => "Webhook not found"}
         }}
      end)

      assert {:error, :not_found, %HttpFailure{}} =
               Console.delete_webhook("wh_missing", client: @client)
    end
  end

  describe "list_hid_orgs/1" do
    test "returns {:ok, orgs} on success" do
      response_body = [
        %{
          "id" => "org_abc123",
          "name" => "Acme HQ",
          "slug" => "acme-hq",
          "first_name" => "Alice",
          "last_name" => "Liddell",
          "phone" => "+1-555-0100",
          "full_address" => "1 Wonder Lane, NY",
          "status" => "active",
          "created_at" => "2026-05-01T10:00:00Z"
        }
      ]

      expect(mock_http_client(), :get, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/console/hid/orgs"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, orgs} = Console.list_hid_orgs(client: @client)
      assert [%HidOrg{} = first] = orgs
      assert first.id == "org_abc123"
      assert first.name == "Acme HQ"
      assert first.slug == "acme-hq"
      assert first.status == "active"
    end

    test "returns {:ok, []} when there are no HID orgs" do
      expect(mock_http_client(), :get, fn _url, _opts ->
        {:ok, %HttpResponse{status: 200, body_decoded: []}}
      end)

      assert {:ok, []} = Console.list_hid_orgs(client: @client)
    end
  end

  describe "create_hid_org/2" do
    test "returns {:ok, HidOrg} on 201" do
      response_body = %{
        "id" => "org_new789",
        "name" => "Test Org",
        "slug" => "test-org",
        "first_name" => "Test",
        "last_name" => "User",
        "phone" => "+1-555-0101",
        "full_address" => "2 Test St, NY",
        "status" => "pending",
        "created_at" => "2026-05-17T12:00:00Z"
      }

      expect(mock_http_client(), :post, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/console/hid/orgs"
        assert opts[:body][:name] == "Test Org"
        assert opts[:body][:first_name] == "Test"
        {:ok, %HttpResponse{status: 201, body_decoded: response_body}}
      end)

      assert {:ok, %HidOrg{} = org} =
               Console.create_hid_org(
                 %{
                   name: "Test Org",
                   full_address: "2 Test St, NY",
                   phone: "+1-555-0101",
                   first_name: "Test",
                   last_name: "User"
                 },
                 client: @client
               )

      assert org.id == "org_new789"
      assert org.slug == "test-org"
      assert org.status == "pending"
    end

    test "returns {:error, :validation_failed, failure} on 422" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 422,
           reason: :unprocessable_entity,
           body_decoded: %{"message" => ["Name can't be blank"]}
         }}
      end)

      assert {:error, :validation_failed, %HttpFailure{}} =
               Console.create_hid_org(
                 %{
                   name: "X",
                   full_address: "1 Main St",
                   phone: "+1-555-0101",
                   first_name: "A",
                   last_name: "B"
                 },
                 client: @client
               )
    end
  end

  describe "activate_hid_org/2" do
    test "returns {:ok, HidOrg} on 200 (job enqueued)" do
      response_body = %{
        "id" => "org_abc123",
        "name" => "Acme HQ",
        "slug" => "acme-hq",
        "first_name" => "Alice",
        "last_name" => "Liddell",
        "phone" => "+1-555-0100",
        "full_address" => "1 Wonder Lane, NY",
        "status" => "activating",
        "created_at" => "2026-05-01T10:00:00Z"
      }

      expect(mock_http_client(), :post, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/console/hid/orgs/activate"
        assert opts[:body][:email] == "alice@example.com"
        assert opts[:body][:password] == "secret"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %HidOrg{} = org} =
               Console.activate_hid_org(
                 %{email: "alice@example.com", password: "secret"},
                 client: @client
               )

      assert org.id == "org_abc123"
      assert org.status == "activating"
    end

    test "returns {:error, :not_found, failure} on 404" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 404,
           reason: :not_found,
           body_decoded: %{"message" => "Organization not found"}
         }}
      end)

      assert {:error, :not_found, %HttpFailure{}} =
               Console.activate_hid_org(
                 %{email: "missing@example.com", password: "x"},
                 client: @client
               )
    end
  end

  describe "list_ledger_items/1" do
    test "returns {:ok, items, pagination} on success" do
      response_body = %{
        "ledger_items" => [
          %{
            "id" => "li_abc123",
            "ex_id" => "li_abc123",
            "created_at" => "2026-05-01T10:00:00Z",
            "amount" => 250,
            "kind" => "ap_debit",
            "event" => "ag.access_pass.issued",
            "metadata" => %{"reason" => "issuance"},
            "access_pass" => %{
              "id" => "ap_111",
              "ex_id" => "ap_111",
              "full_name" => "Alice Liddell",
              "state" => "active",
              "metadata" => %{"dept" => "Eng"},
              "unified_access_pass_id" => "uap_222",
              "pass_template" => %{
                "id" => "tpl_333",
                "ex_id" => "tpl_333",
                "name" => "Employee Badge",
                "protocol" => "desfire",
                "platform" => "apple",
                "use_case" => "corporate_id"
              }
            }
          },
          %{
            "id" => "li_def456",
            "ex_id" => "li_def456",
            "created_at" => "2026-05-02T10:00:00Z",
            "amount" => 100,
            "kind" => "pt_debit",
            "event" => "ag.card_template.published",
            "metadata" => %{},
            "access_pass" => nil
          }
        ],
        "pagination" => %{
          "current_page" => 1,
          "per_page" => 50,
          "total_pages" => 1,
          "total_count" => 2
        }
      }

      expect(mock_http_client(), :get, fn url, _opts ->
        assert url == "https://api.accessgrid.com/v1/console/ledger-items"
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, items, pagination} = Console.list_ledger_items(client: @client)
      assert [%LedgerItem{} = first, %LedgerItem{} = second] = items

      assert first.id == "li_abc123"
      assert first.amount == 250
      assert first.kind == "ap_debit"
      assert first.event == "ag.access_pass.issued"

      assert %LedgerItem.AccessPass{} = first.access_pass
      assert first.access_pass.id == "ap_111"
      assert first.access_pass.full_name == "Alice Liddell"
      assert first.access_pass.unified_access_pass_id == "uap_222"

      assert %LedgerItem.CardTemplate{} = first.access_pass.pass_template
      assert first.access_pass.pass_template.id == "tpl_333"
      assert first.access_pass.pass_template.platform == "apple"
      assert first.access_pass.pass_template.use_case == "corporate_id"

      assert second.access_pass == nil
      assert pagination["total_count"] == 2
    end

    test "returns {:ok, [], pagination} when there are no ledger items" do
      expect(mock_http_client(), :get, fn _url, _opts ->
        {:ok,
         %HttpResponse{
           status: 200,
           body_decoded: %{"ledger_items" => [], "pagination" => %{"total_count" => 0}}
         }}
      end)

      assert {:ok, [], _pagination} = Console.list_ledger_items(client: @client)
    end

    test "passes pagination params" do
      expect(mock_http_client(), :get, fn _url, opts ->
        assert opts[:params][:page] == 3
        assert opts[:params][:per_page] == 25
        {:ok, %HttpResponse{status: 200, body_decoded: %{"ledger_items" => [], "pagination" => %{}}}}
      end)

      Console.list_ledger_items(client: @client, page: 3, per_page: 25)
    end

    test "passes date filter params" do
      expect(mock_http_client(), :get, fn _url, opts ->
        assert opts[:params][:start_date] == "2026-05-01T00:00:00Z"
        assert opts[:params][:end_date] == "2026-05-31T23:59:59Z"
        {:ok, %HttpResponse{status: 200, body_decoded: %{"ledger_items" => [], "pagination" => %{}}}}
      end)

      Console.list_ledger_items(
        client: @client,
        start_date: "2026-05-01T00:00:00Z",
        end_date: "2026-05-31T23:59:59Z"
      )
    end

    test "returns {:error, :validation_failed, failure} on bad date format" do
      expect(mock_http_client(), :get, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 422,
           reason: :unprocessable_entity,
           body_decoded: %{"message" => "Invalid start_date format. Must be ISO8601"}
         }}
      end)

      assert {:error, :validation_failed, %HttpFailure{}} =
               Console.list_ledger_items(client: @client, start_date: "not-a-date")
    end
  end

  describe "publish_template/2" do
    test "returns {:ok, PublishResult} with status publishing on 200" do
      response_body = %{"id" => "tpl_abc123", "status" => "publishing"}

      expect(mock_http_client(), :post, fn url, opts ->
        assert url == "https://api.accessgrid.com/v1/console/card-templates/tpl_abc123/publish"
        # Empty-body POST: signature is verified via sig_payload query param
        assert opts[:params]["sig_payload"] == ~s({"id":"tpl_abc123"})
        assert opts[:body] == nil
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %CardTemplate.PublishResult{} = result} =
               Console.publish_template("tpl_abc123", client: @client)

      assert result.id == "tpl_abc123"
      assert result.status == "publishing"
    end

    test "returns {:ok, PublishResult} with status ready (Android immediate publish)" do
      response_body = %{"id" => "tpl_android_42", "status" => "ready"}

      expect(mock_http_client(), :post, fn _url, _opts ->
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %CardTemplate.PublishResult{status: "ready"}} =
               Console.publish_template("tpl_android_42", client: @client)
    end

    test "returns {:error, :not_found, failure} on 404" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 404,
           reason: :not_found,
           body_decoded: %{"message" => "Card template not found"}
         }}
      end)

      assert {:error, :not_found, %HttpFailure{}} =
               Console.publish_template("tpl_missing", client: @client)
    end

    test "returns {:error, :validation_failed, failure} on HID-sync 422 for Android+SEOS" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 422,
           reason: :unprocessable_entity,
           body_decoded: %{
             "status" => "error",
             "message" => ["hid_account_org HID portal sync failed"]
           }
         }}
      end)

      assert {:error, :validation_failed, %HttpFailure{} = failure} =
               Console.publish_template("tpl_android_seos", client: @client)

      assert failure.body_decoded["message"] == ["hid_account_org HID portal sync failed"]
    end
  end

  describe "reveal_smart_tap/2" do
    # Captured server envelope + the matching caller keypair. Lets us assert
    # the SDK end-to-end (HTTP → decrypt → struct) using a real server
    # payload, by injecting the captured keypair via the `:keypair` opt so
    # the SDK uses it instead of generating a fresh one.
    @fixture_caller_private_key_pem """
    -----BEGIN EC PRIVATE KEY-----
    MHcCAQEEIIou+Kk08kWAjhi0WyIx+L2GrgStGBCPODlwKYKd5BydoAoGCCqGSM49
    AwEHoUQDQgAE+gnDxXJt1SBaCK8roKH8QvOa/ItdQUe85JIsUc6RvhD/udLaFtHY
    m+MnOmeSdVaKTPWudH0+iGbleB3kS7lYxQ==
    -----END EC PRIVATE KEY-----
    """

    @fixture_envelope %{
      "alg" => "ECDH-ES+A256GCM",
      "ciphertext" => "ckYyA3FdRYjOFI/FKz/QeR5Yf9nZZFzo73kDXKZSB/EgbQ==",
      "ephemeral_public_key" =>
        "-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE7mg6i99GcIVutMPr/PXSBSQVlbLM\ntnJO10ZBjk9ZTfw6wwAVNBnDBiqY7VrdOG1JdFOYoac+NkAlyMRGYk2tVQ==\n-----END PUBLIC KEY-----\n",
      "iv" => "5X2OCht+kLB/xQmX",
      "tag" => "0vwkjVaCwi5zl37xvJPxeg=="
    }

    @fixture_expected_plaintext "FIXTURE-PLAINTEXT-NOT-A-CREDENTIAL"

    defp fixture_keypair do
      [pem_entry] = :public_key.pem_decode(@fixture_caller_private_key_pem)
      ec_priv = :public_key.pem_entry_decode(pem_entry)
      {:ECPrivateKey, _, _, params, pub_point, _} = ec_priv

      pub_pem =
        :public_key.pem_encode([
          :public_key.pem_entry_encode(:SubjectPublicKeyInfo, {{:ECPoint, pub_point}, params})
        ])

      {ec_priv, pub_pem}
    end

    test "returns {:ok, %SmartTapReveal{private_key: pem}} on 200" do
      {_ec_priv, pub_pem} = fixture_keypair()

      response_body = %{
        "key_version" => "tmpl-42",
        "collector_id" => "12345678",
        "fingerprint" => "sha256:deadbeef",
        "encrypted_private_key" => @fixture_envelope
      }

      expect(mock_http_client(), :post, fn url, opts ->
        assert url ==
                 "https://api.accessgrid.com/v1/console/card-templates/tpl_abc123/smart-tap/reveal"

        assert opts[:body][:client_public_key] == pub_pem
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:ok, %SmartTapReveal{} = reveal} =
               Console.reveal_smart_tap("tpl_abc123",
                 client: @client,
                 keypair: fixture_keypair()
               )

      assert reveal.key_version == "tmpl-42"
      assert reveal.collector_id == "12345678"
      assert reveal.fingerprint == "sha256:deadbeef"
      assert reveal.private_key == @fixture_expected_plaintext
      assert reveal.encrypted_private_key == @fixture_envelope
    end

    test "generates a fresh keypair when :keypair isn't injected" do
      expect(mock_http_client(), :post, fn _url, opts ->
        # Just assert the SDK put a SubjectPublicKeyInfo PEM on the wire —
        # we can't decrypt without the matching priv, so we short-circuit
        # with a server-side validation_failed response.
        assert opts[:body][:client_public_key] =~ "-----BEGIN PUBLIC KEY-----"

        {:error,
         %HttpFailure{
           status: 422,
           reason: :unprocessable_entity,
           body_decoded: %{"status" => "error", "message" => "stub"}
         }}
      end)

      assert {:error, :validation_failed, %HttpFailure{}} =
               Console.reveal_smart_tap("tpl_abc123", client: @client)
    end

    test "returns {:error, :decrypt_failed, body} when the envelope can't be decrypted" do
      response_body = %{
        "key_version" => "tmpl-42",
        "collector_id" => "12345678",
        "fingerprint" => "sha256:deadbeef",
        "encrypted_private_key" => Map.put(@fixture_envelope, "tag", "AAAAAAAAAAAAAAAAAAAAAA==")
      }

      expect(mock_http_client(), :post, fn _url, _opts ->
        {:ok, %HttpResponse{status: 200, body_decoded: response_body}}
      end)

      assert {:error, :decrypt_failed, ^response_body} =
               Console.reveal_smart_tap("tpl_abc123",
                 client: @client,
                 keypair: fixture_keypair()
               )
    end

    test "returns {:error, :not_found, failure} on 404" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 404,
           reason: :not_found,
           body_decoded: %{"status" => "error", "message" => "Card template not found"}
         }}
      end)

      assert {:error, :not_found, %HttpFailure{}} =
               Console.reveal_smart_tap("tpl_missing", client: @client)
    end

    test "returns {:error, :conflict, failure} on 409 (single-use pubkey)" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 409,
           reason: :conflict,
           body_decoded: %{
             "status" => "error",
             "message" => "client_public_key has already been used"
           }
         }}
      end)

      assert {:error, :conflict, %HttpFailure{}} =
               Console.reveal_smart_tap("tpl_abc123", client: @client)
    end

    test "returns {:error, :validation_failed, failure} on 422" do
      expect(mock_http_client(), :post, fn _url, _opts ->
        {:error,
         %HttpFailure{
           status: 422,
           reason: :unprocessable_entity,
           body_decoded: %{"status" => "error", "message" => "Invalid client_public_key"}
         }}
      end)

      assert {:error, :validation_failed, %HttpFailure{}} =
               Console.reveal_smart_tap("tpl_abc123", client: @client)
    end
  end

  describe "client resolution" do
    test "uses client from config when not provided" do
      # Set up config for this test
      Gestalt.replace_config(:accessgrid, :account_id, "config_acct", self())
      Gestalt.replace_config(:accessgrid, :api_secret, "config_secret", self())
      Gestalt.replace_config(:accessgrid, :api_host, "https://config.accessgrid.com", self())

      expect(mock_http_client(), :get, fn url, opts ->
        # Verify it used the config-based host
        assert url == "https://config.accessgrid.com/v1/console/card-templates/tpl_123"
        # Verify auth headers are present (from config-based client)
        assert Map.has_key?(opts[:headers], "X-ACCT-ID")
        assert opts[:headers]["X-ACCT-ID"] == "config_acct"
        assert Map.has_key?(opts[:headers], "X-PAYLOAD-SIG")
        {:ok, %HttpResponse{status: 200, body_decoded: %{}}}
      end)

      # Don't pass client: option - should use config
      Console.read_template("tpl_123")
    end
  end

  describe "local required-field validation" do
    # These tests short-circuit before HTTP — no mock expectations needed.
    # Each verifies that the SDK returns {:error, :missing_required, [keys]}
    # without ever calling out, surfacing "you forgot X" locally.

    test "update_template requires template_id" do
      assert {:error, :missing_required, [:template_id]} =
               Console.update_template(nil, %{name: "X"}, client: @client)

      assert {:error, :missing_required, [:template_id]} =
               Console.update_template("", %{name: "X"}, client: @client)
    end

    test "read_template requires template_id" do
      assert {:error, :missing_required, [:template_id]} =
               Console.read_template(nil, client: @client)
    end

    test "get_logs requires template_id" do
      assert {:error, :missing_required, [:template_id]} =
               Console.get_logs(nil, client: @client)
    end

    test "ios_preflight requires template_id and access_pass_ex_id" do
      assert {:error, :missing_required, [:template_id]} =
               Console.ios_preflight(nil, %{access_pass_ex_id: "ap_1"}, client: @client)

      assert {:error, :missing_required, [:access_pass_ex_id]} =
               Console.ios_preflight("tpl_1", %{}, client: @client)
    end

    test "publish_template requires template_id" do
      assert {:error, :missing_required, [:template_id]} =
               Console.publish_template(nil, client: @client)
    end

    test "reveal_smart_tap requires template_id" do
      assert {:error, :missing_required, [:template_id]} =
               Console.reveal_smart_tap(nil, client: @client)
    end

    test "create_card_template_pair requires name, apple_card_template_id, google_card_template_id" do
      assert {:error, :missing_required, [:name, :apple_card_template_id, :google_card_template_id]} =
               Console.create_card_template_pair(%{}, client: @client)
    end

    test "create_landing_page requires name and kind" do
      assert {:error, :missing_required, [:name, :kind]} =
               Console.create_landing_page(%{}, client: @client)
    end

    test "update_landing_page requires landing_page_id" do
      assert {:error, :missing_required, [:landing_page_id]} =
               Console.update_landing_page(nil, %{name: "X"}, client: @client)
    end

    test "create_credential_profile requires name and keys" do
      assert {:error, :missing_required, [:name, :keys]} =
               Console.create_credential_profile(%{}, client: @client)
    end

    test "create_webhook requires name, url, subscribed_events" do
      assert {:error, :missing_required, [:name, :url, :subscribed_events]} =
               Console.create_webhook(%{}, client: @client)
    end

    test "delete_webhook requires webhook_id" do
      assert {:error, :missing_required, [:webhook_id]} =
               Console.delete_webhook(nil, client: @client)
    end

    test "create_hid_org requires all five contact fields" do
      assert {:error, :missing_required, [:name, :full_address, :phone, :first_name, :last_name]} =
               Console.create_hid_org(%{}, client: @client)
    end

    test "activate_hid_org requires email and password" do
      assert {:error, :missing_required, [:email, :password]} =
               Console.activate_hid_org(%{}, client: @client)
    end
  end
end
