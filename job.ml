(** 
   The basic execution unit.
   @author Miles Egan
   @version $Rev: 86 $
   @id $Id$
 *)

type rsh_type = Ssh | Rsh | Pixrsh

class job user prog command host =
  let (p_read, p_write) = Unix.pipe () in
  let pid = match Unix.fork () with
    0 ->  
      begin
        close_in stdin;
        close_out stdout;
        Unix.close p_read;
        Unix.dup2 p_write Unix.stdout;
        Unix.dup2 p_write Unix.stderr;
        let (exe, opts)  = match prog with
          Ssh -> ("ssh", 
                  [| "-n"; 
                     "-l"; user;
                     "-o"; "PasswordAuthentication no"; 
                     "-o"; "StrictHostKeyChecking no"; 
                     "-o"; "FallBackToRsh no" |])
        | Rsh -> ("rsh", [|"-n"; "-l"; user |])
        | Pixrsh -> ("pixrsh", [||])
        in
        Unix.execvp exe (Array.append [| exe |] (Array.append opts [| host; command |]))
      end;
      0
  | pid -> 
      begin
        Unix.close p_write; 
        pid
      end
  in
  object (self)
    val channel = Unix.in_channel_of_descr p_read
    val mutable finished = false
    val host = host
    val pid = pid 
    val pipe = p_read
    val timeouts = 0 

    (** simple accessors *)
    method finished = finished
    method host = host
    method pipe = pipe
    method timeouts = timeouts

    (** reads one line from the job's output channel. *)
    method read =
      try
        input_line channel
      with End_of_file -> begin self#terminate; "" end

    (** ends the job and cleans up after it. *)
    method terminate = 
      begin
        close_in channel;
        finished <- true
      end

    (** increments the jobs timeout count *)
    method timeout = {< timeouts = timeouts + 1 >}
  end
  
