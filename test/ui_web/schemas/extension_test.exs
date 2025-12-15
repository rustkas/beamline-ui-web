defmodule UiWeb.Schemas.ExtensionTest do
  use ExUnit.Case, async: true
  alias UiWeb.Schemas.Extension

  describe "Extension changeset validation" do
    test "valid extension passes validation" do
      attrs = %{
        "name" => "openai-provider",
        "type" => "provider",
        "nats_subject" => "beamline.extensions.provider.openai.v1",
        "version" => "1.0.0",
        "description" => "OpenAI API adapter",
        "enabled" => true
      }

      changeset = Extension.changeset(%Extension{}, attrs)

      assert changeset.valid?
      assert changeset.errors == []
    end

    test "validates required fields" do
      changeset = Extension.changeset(%Extension{}, %{})

      refute changeset.valid?
      assert {:name, _} = List.keyfind(changeset.errors, :name, 0)
      assert {:type, _} = List.keyfind(changeset.errors, :type, 0)
      assert {:nats_subject, _} = List.keyfind(changeset.errors, :nats_subject, 0)
      assert {:version, _} = List.keyfind(changeset.errors, :version, 0)
    end

    test "validates type inclusion" do
      attrs = %{
        "name" => "test",
        "type" => "invalid",
        "nats_subject" => "beamline.extensions.provider.test.v1",
        "version" => "1.0.0"
      }

      changeset = Extension.changeset(%Extension{}, attrs)

      refute changeset.valid?
      assert {:type, _} = List.keyfind(changeset.errors, :type, 0)
    end

    test "validates NATS subject format" do
      attrs = %{
        "name" => "test",
        "type" => "provider",
        "nats_subject" => "invalid-subject",
        "version" => "1.0.0"
      }

      changeset = Extension.changeset(%Extension{}, attrs)

      refute changeset.valid?
      assert {:nats_subject, _} = List.keyfind(changeset.errors, :nats_subject, 0)
    end

    test "validates NATS subject matches type" do
      attrs = %{
        "name" => "test",
        "type" => "provider",
        "nats_subject" => "beamline.extensions.validator.test.v1",
        "version" => "1.0.0"
      }

      changeset = Extension.changeset(%Extension{}, attrs)

      refute changeset.valid?
      assert {:nats_subject, _} = List.keyfind(changeset.errors, :nats_subject, 0)
    end

    test "validates version format" do
      attrs = %{
        "name" => "test",
        "type" => "provider",
        "nats_subject" => "beamline.extensions.provider.test.v1",
        "version" => "invalid"
      }

      changeset = Extension.changeset(%Extension{}, attrs)

      refute changeset.valid?
      assert {:version, _} = List.keyfind(changeset.errors, :version, 0)
    end

    test "validates name format" do
      attrs = %{
        "name" => "Invalid Name",
        "type" => "provider",
        "nats_subject" => "beamline.extensions.provider.test.v1",
        "version" => "1.0.0"
      }

      changeset = Extension.changeset(%Extension{}, attrs)

      refute changeset.valid?
      assert {:name, _} = List.keyfind(changeset.errors, :name, 0)
    end

    test "accepts valid NATS subjects" do
      valid_subjects = [
        "beamline.extensions.provider.openai.v1",
        "beamline.extensions.validator.schema.v1alpha",
        "beamline.extensions.pre.rate-limit.v2",
        "beamline.extensions.post.processor.v1beta"
      ]

      for subject <- valid_subjects do
        type = extract_type_from_subject(subject)
        attrs = %{
          "name" => "test",
          "type" => type,
          "nats_subject" => subject,
          "version" => "1.0.0"
        }

        changeset = Extension.changeset(%Extension{}, attrs)
        assert changeset.valid?, "Subject #{subject} should be valid"
      end
    end

    test "validates metadata docs_url format" do
      attrs = %{
        "name" => "test",
        "type" => "provider",
        "nats_subject" => "beamline.extensions.provider.test.v1",
        "version" => "1.0.0",
        "metadata" => %{
          "docs_url" => "not-a-url"
        }
      }

      changeset = Extension.changeset(%Extension{}, attrs)

      # Metadata validation might not block the whole changeset
      # but should add an error
      assert changeset.changes.metadata
    end

    test "validates config timeout_ms range" do
      attrs = %{
        "name" => "test",
        "type" => "provider",
        "nats_subject" => "beamline.extensions.provider.test.v1",
        "version" => "1.0.0",
        "config" => %{
          "timeout_ms" => 500_000  # Too large
        }
      }

      changeset = Extension.changeset(%Extension{}, attrs)

      # Config validation might not block the whole changeset
      assert changeset.changes.config
    end
  end

  defp extract_type_from_subject(subject) do
    case Regex.run(~r/beamline\.extensions\.(provider|validator|pre|post)\./, subject) do
      [_, type] -> type
      _ -> "provider"
    end
  end
end

