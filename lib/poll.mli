(** A direct binding of poll(2). *)

(** Main type for a poller. *)
type t

val create : ?maxfds:int -> unit -> t
(** [create ?maxfds ()] creates a new poller.
    @param maxfds Maximum number of fds, defaults to {!Util.max_open_files}. *)

val maxfds : t -> int
(** [maxfds t] is the maximum number of file descriptor slots allocated for [t]. *)

(** The set of flags associated with a file descriptor event. *)
module Flags : sig

  type output = < output: unit; >

  type 'a input = < .. > as 'a

  type input_only = < >

  type 'inout t
  (** The actual set. *)

  val pollin : 'a input t
  (** POLLIN from poll(2). *)

  val pollpri : 'a input t
  (** POLLPRI from poll(2). *)

  val pollout : 'a input t
  (** POLLOUT from poll(2). *)

  val pollerr : output t
  (** POLLERR from poll(2). Only expected as output, invalid as input. *)

  val pollhup : output t
  (** POLLHUP from poll(2). Only expected as output, invalid as input. *)

  val pollnval : output t
  (** POLLNVAL from poll(2). Only expected as output, invalid as input. *)

  val empty : 'a input t
  (** aka zero. *)

  val ( + ) : 'a t -> 'a t -> 'a t
  (** The union of flags, fancy way of doing {!lor}. *)

  val mem : 'a t -> 'b t -> bool
  (** [mem x y] checks if [y] belongs to [m]. The fancy way of doing {!land}. *)

  val to_int : 'inout t -> int
  (** [to_int x] exposes [x] as an integer, this is an identity function. *)

  val of_int : int -> 'inout t
  (** [of_int x] imports [x] as {!t}, this is an identity function. *)

  val input_of_int : int -> input_only t
end

val invalid_fd : Unix.file_descr
(** [invalid_fd] is the {!Unix.file_descr} of value -1. *)

(** The timeout parameter for {!poll}. *)
type poll_timeout =
  | Infinite             (** No timeout, wait forever *)
  | Nowait               (** Don't block, return immediately *)
  | Milliseconds of int  (** Block for at most [int] milliseconds *)

(** The actual poll(2) call *)
val poll : t -> int -> poll_timeout -> int
(** [poll t nfds timeout] polls for the first [nfds], like the system
    call, invalid (-1) entries are ignored. The internal buffer is not
    modified after the call. It returns the number of ready file
    descriptors suitable to be used with {!iter_ready}. *)

(** The timeout parameter for {!ppoll}. Supports nanoseconds instead of milliseconds. *)
type ppoll_timeout =
  | Infinite              (** No timeout, wait forever *)
  | Nowait                (** Don't block, return immediately *)
  | Nanoseconds of int64  (** Block for at most [int64] nanoseconds *)

(** The actual ppoll(2) call *)
val ppoll : t -> int -> ppoll_timeout -> int list -> int
(** [ppoll t nfds timeout sigmask] is like {!poll} but supports
    nanoseconds and a list of signals that are atomically masked
    during execution and restored uppon return. *)

val set_index : t -> int -> Unix.file_descr -> Flags.input_only Flags.t -> unit
(** [set_index t index fd flag] modifies the internal buffer at
    [index] to listen to [flag] events of [fd]. This overwrites any
    previous value of [flag] and [fd] internally. {!invalid_fd} (-1)
    can be used to deactivate the slot, but usage of
    {!invalidate_index} is preferred. *)

val invalidate_index : t -> int -> unit
(** [invalidate_index t index] modifies the internal buffer by
    invalidating [index]. The kernel will ignore that slot. We also
    clear flags, just for kicks. *)

val get_revents : t -> int -> Flags.output Flags.t
(** [get_revents t index] is the returned event flags set after a call
    to {!poll} or {!ppoll}. *)

val get_fd : t -> int -> Unix.file_descr
(** [get_fd t index] is the file descriptor associated with [index]. *)

val iter_ready : t -> int -> (int -> Unix.file_descr -> Flags.output Flags.t -> unit) -> unit
(** [iter_ready t nready fn] scans the internal buffer for every ready
    file descriptor and calls [fn index fd flags], the scanning is
    aborted after [nready] entries are found. Invalid file descriptors
    (set to -1 via invalidate_index) are skipped. Typical usage is that
    [nready] is the return of {!poll} or {!ppoll}. The internal buffer
    is left unmodified. *)
