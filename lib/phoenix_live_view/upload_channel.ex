defmodule Phoenix.LiveView.UploadChannel do
  @moduledoc false
  use Phoenix.Channel

  require Logger

  alias Phoenix.LiveView
  alias Phoenix.LiveView.{Socket, View, Diff}

  alias Phoenix.LiveView.UploadFrame

  def join(topic, auth_payload, socket) do
    %{"ref" => ref} = auth_payload

    with {:ok, %{pid: pid}} <- Phoenix.LiveView.View.verify_token(socket.endpoint, ref),
         :ok <-
           GenServer.call(pid, {:phoenix, :register_file_upload, %{pid: self(), ref: topic}}),
         {:ok, path} <- Plug.Upload.random_file("live_view_upload"),
         {:ok, handle} <- File.open(path, [:binary, :write]) do

      Process.monitor(pid)

      socket =
        socket
        |> Phoenix.Socket.assign(:path, path)
        |> Phoenix.Socket.assign(:handle, handle)
        |> Phoenix.Socket.assign(:live_view_pid, pid)

      {:ok, %{}, socket}
    else
      {:error, :limit_exceeded} -> {:error, %{reason: :limit_exceeded}}
      _ -> {:error, %{reason: :invalid_token}}
    end
  end

  def handle_in("event", {:frame, payload}, socket) do
    IO.binwrite(socket.assigns.handle, payload)
    {:reply, {:ok, %{file_ref: socket.join_ref}}, socket}
  end

  @impl true
  def handle_call({:get_file, ref}, _reply, socket) do
    File.close(socket.assigns.handle)
    {:reply, {:ok, socket.assigns.path}, socket}
  end

  def handle_cast(:stop, socket) do
    {:stop, :normal, socket}
  end

  def handle_info(
        {:DOWN, _, _, live_view_pid, reason},
        %{assigns: %{live_view_pid: livd_view_pid}} = state
      ) do
    reason = if reason == :normal, do: {:shutdown, :closed}, else: reason
    {:stop, reason, state}
  end
end
