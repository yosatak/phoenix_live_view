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
         :ok <- GenServer.call(pid, {:phoenix, :register_file_upload, %{pid: self(), ref: topic}}) do
      {:ok, %{}, socket}
    else
      {:error, :limit_exceeded} -> {:error, %{reason: :limit_exceeded}}
      _ -> {:error, %{reason: :invalid_token}}
    end
  end

  def handle_in("event", {:frame, payload}, socket) do
    {:reply, {:ok, %{file_ref: "1"}}, add_frame(socket, payload)}
  end

  defp add_frame(socket, frame) do
    frames =
      case socket.assigns do
        %{frames: frames} -> [frame | frames]
        _ -> [frame]
      end
    Phoenix.Socket.assign(socket, :frames, frames)
  end

  @impl true
  def handle_call({:get_file, ref}, _reply, %{assigns: %{frames: frames}} = state) do
    # TODO: change this upload mechanism?
    path = Plug.Upload.random_file!("multipart")
    File.write(path, Enum.reverse(frames))
    {:reply, {:ok, path}, %{state | assigns: %{frames: []}}}
  end

  def handle_call(:stop, _reply, state) do
    IO.inspect :stopping
    {:stop, :finished, state}
  end

  # TODO shutdown channel from the client on a liveview crash
end
