defmodule Bytepack.Accounts.UserTOTP do
  use Bytepack.Schema
  import Ecto.Changeset

  schema "users_totps" do
    field :secret, :binary
    field :code, :string, virtual: true
    belongs_to :user, Bytepack.Accounts.User

    embeds_many :backup_codes, BackupCode, on_replace: :delete do
      field :code, :string
      field :used_at, :utc_datetime_usec
    end

    timestamps()
  end

  def changeset(totp, attrs) do
    changeset =
      totp
      |> cast(attrs, [:code])
      |> validate_required([:code])
      |> validate_format(:code, ~r/^\d{6}$/, message: "should be a 6 digit number")

    code = Ecto.Changeset.get_field(changeset, :code)

    if changeset.valid? and not valid_totp?(totp, code) do
      Ecto.Changeset.add_error(changeset, :code, "invalid code")
    else
      changeset
    end
  end

  def valid_totp?(totp, code) do
    is_binary(code) and byte_size(code) == 6 and NimbleTOTP.valid?(totp.secret, code)
  end

  def validate_backup_code(totp, code) when is_binary(code) do
    totp.backup_codes
    |> Enum.map_reduce(false, fn backup, valid? ->
      if Plug.Crypto.secure_compare(backup.code, code) and is_nil(backup.used_at) do
        {Ecto.Changeset.change(backup, %{used_at: DateTime.utc_now()}), true}
      else
        {backup, valid?}
      end
    end)
    |> case do
      {backup_codes, true} ->
        totp
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.put_embed(:backup_codes, backup_codes)

      {_, false} ->
        nil
    end
  end

  def validate_backup_code(_totp, _code), do: nil

  def regenerate_backup_codes(changeset) do
    Ecto.Changeset.put_embed(changeset, :backup_codes, generate_backup_codes())
  end

  def ensure_backup_codes(changeset) do
    case Ecto.Changeset.get_field(changeset, :backup_codes) do
      [] -> regenerate_backup_codes(changeset)
      _ -> changeset
    end
  end

  defp generate_backup_codes do
    for letter <- Enum.take_random(?A..?Z, 10) do
      suffix =
        :crypto.strong_rand_bytes(5)
        |> Base.encode32()
        |> binary_part(0, 7)

      # The first digit is always a letter so we can distinguish
      # in the UI between 6 digit TOTP codes and backup ones.
      # We also replace the letter O by X to avoid confusion with zero.
      code = String.replace(<<letter, suffix::binary>>, "O", "X")
      %Bytepack.Accounts.UserTOTP.BackupCode{code: code}
    end
  end
end
