# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.PleromaAuthenticator do
  alias Comeonin.Pbkdf2
  alias Pleroma.Registration
  alias Pleroma.Repo
  alias Pleroma.User

  @behaviour Pleroma.Web.Auth.Authenticator

  def get_user(%Plug.Conn{} = _conn, params) do
    {name, password} =
      case params do
        %{"authorization" => %{"name" => name, "password" => password}} ->
          {name, password}

        %{"grant_type" => "password", "username" => name, "password" => password} ->
          {name, password}
      end

    with {_, %User{} = user} <- {:user, User.get_by_nickname_or_email(name)},
         {_, true} <- {:checkpw, Pbkdf2.checkpw(password, user.password_hash)} do
      {:ok, user}
    else
      error ->
        {:error, error}
    end
  end

  def get_registration(
        %Plug.Conn{assigns: %{ueberauth_auth: %{provider: provider, uid: uid} = auth}},
        _params
      ) do
    registration = Registration.get_by_provider_uid(provider, uid)

    if registration do
      {:ok, registration}
    else
      info = auth.info

      Registration.changeset(%Registration{}, %{
        provider: to_string(provider),
        uid: to_string(uid),
        info: %{
          "nickname" => info.nickname,
          "email" => info.email,
          "name" => info.name,
          "description" => info.description
        }
      })
      |> Repo.insert()
    end
  end

  def get_registration(%Plug.Conn{} = _conn, _params), do: {:error, :missing_credentials}

  def create_from_registration(_conn, params, registration) do
    nickname = value([params["nickname"], Registration.nickname(registration)])
    email = value([params["email"], Registration.email(registration)])
    name = value([params["name"], Registration.name(registration)]) || nickname
    bio = value([params["bio"], Registration.description(registration)])

    random_password = :crypto.strong_rand_bytes(64) |> Base.encode64()

    with {:ok, new_user} <-
           User.register_changeset(
             %User{},
             %{
               email: email,
               nickname: nickname,
               name: name,
               bio: bio,
               password: random_password,
               password_confirmation: random_password
             },
             external: true,
             confirmed: true
           )
           |> Repo.insert(),
         {:ok, _} <-
           Registration.changeset(registration, %{user_id: new_user.id}) |> Repo.update() do
      {:ok, new_user}
    end
  end

  defp value(list), do: Enum.find(list, &(to_string(&1) != ""))

  def handle_error(%Plug.Conn{} = _conn, error) do
    error
  end

  def auth_template, do: nil

  def oauth_consumer_template, do: nil
end