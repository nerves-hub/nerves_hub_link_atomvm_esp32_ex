# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later

defmodule AtomVMModules do
  @moduledoc """
  What a module can call and still run on AtomVM.

  AtomVM ships a subset of both standard libraries, and the gaps are not the
  ones you would guess: there is no `String`, no `Atom`, no `Application`, no
  `Task`. Calling one compiles cleanly, passes every test on the host, and then
  fails on the device with `Failed load module`.

  This list is the module names in an AtomVM checkout, from

      libs/exavmlib/lib/*.ex
      libs/estdlib/src/*.erl
      libs/eavmlib/src/*.erl
      libs/alisp/src/*.erl

  plus the modules the VM itself provides. Regenerate it against the AtomVM
  version being targeted when that moves.
  """

  @elixir ~w(
    AVMPort Access ArgumentError ArithmeticError BadArityError BadBooleanError
    BadFunctionError BadMapError BadStructError Base Bitwise CaseClauseError
    Code Collectable Collectable.List Collectable.Map Collectable.MapSet
    CondClauseError Console Enum Enumerable Enumerable.List Enumerable.Map
    Enumerable.MapSet Enumerable.Range ErlangError Exception Function
    FunctionClauseError GPIO GenServer I2C IO Integer Kernel KeyError Keyword
    LEDC List List.Chars List.Chars.Atom List.Chars.BitString
    List.Chars.Float List.Chars.Integer List.Chars.List Map MapSet MatchError
    Module Process Protocol Protocol.UndefinedError Range RuntimeError
    String.Chars String.Chars.Atom String.Chars.BitString String.Chars.Float
    String.Chars.Integer String.Chars.List Supervisor Supervisor.Default
    Supervisor.Spec System SystemLimitError TryClauseError Tuple
    UndefinedFunctionError WithClauseError
  )

  @erlang ~w(
    alisp alisp_stdlib application arepl atomvm avm_pubsub base64 binary
    calendar code code_server console crypto dist_util erl_epmd erlang erpc
    erts_debug erts_internal ets file filename gen gen_event gen_server
    gen_statem gen_tcp gen_tcp_inet gen_tcp_socket gen_udp gen_udp_inet
    gen_udp_socket gpio_hal i2c_hal inet init io io_lib json kernel lists
    logger logger_manager logger_std_h maps math net net_kernel net_kernel_sup
    os port proc_lib proplists queue serial_dist serial_dist_controller sets
    sexp_lexer sexp_parser sexp_serializer socket socket_dist
    socket_dist_controller spi_hal ssl string supervisor sys timer
    timer_manager timestamp_util uart_hal unicode esp gpio i2c ledc spi uart
    network packbeam_api
  )

  @doc "Every module name available on a device."
  def available do
    MapSet.new(Enum.map(@elixir, &:"Elixir.#{&1}") ++ Enum.map(@erlang, &String.to_atom/1))
  end
end
