(** 
   Runon is a tool for batch command execution on a group of hosts.
   @author Miles Egan
   @version $Rev: 98 $
   @id $Id$
 *)

(** {3 global options} *)

let max_timeouts = ref 1
let timeout = ref 15.0
let rsh_cmd = ref Job.Rsh
let rsh_user = ref (Sys.getenv "USER")
let max_queue = ref 10
let hosts_file = ref None
let args = ref []
let version = "1.9"

let options = [
  ("-f", Arg.String (fun x -> hosts_file := Some x), 
   "Read hosts from file instead of command line.");
  ("-n", Arg.Int (fun x -> max_timeouts := x), 
   Printf.sprintf "Number of timeouts before a host is abandoned.  Default is %d." !max_timeouts);
  ("-o", Arg.Unit (fun x -> max_queue := 1), 
   "Run commands one host at a time.  The default is to run commands in parallel.");
  ("-q", Arg.Int (fun x -> max_queue := x), 
   Printf.sprintf "Maximum simultaneous jobs.  Default is %d." !max_queue);
  ("-s", Arg.Unit (fun x -> rsh_cmd := Job.Ssh), 
   "Use ssh instead of rsh.");
  ("-u", Arg.String (fun x -> rsh_user := x), 
   "Log into remote machine as a different user.");
  ("-t", Arg.Float (fun x -> timeout := x), 
   Printf.sprintf "Seconds to wait before timing out a host.  Default is %2.0f seconds." !timeout);
]

(** {3 core functions} *)

(** [read_file file] reads entire contents of file into buffer *)
let read_file file =
  let bsize = 4096 in
  let contents = Buffer.create 16 in
  let readbuf = String.create bsize in
  try
    while true do
      match input file readbuf 0 bsize with
        0 -> raise End_of_file
      |  c -> Buffer.add_substring contents readbuf 0 c
    done;
    Buffer.contents contents
  with End_of_file -> Buffer.contents contents

(**
   [read_hosts_file file] reads a list of hosts from file.
 *)
let read_hosts_file file =
  let f = match file with
    "-" -> stdin | _ -> open_in file in
  Str.split (Str.regexp "[ \r\n\t]+") (read_file f)

(**
   [run_jobs jobs timeout] iterates through jobs looking for jobs with
   unread output.  Times out after timeout seconds.
 *)
let run_jobs jobs timeout = 
  let fds = List.map (fun x -> x#pipe) jobs in
  let (read_fds, write_fds, error_fds) = Unix.select fds [] [] timeout in
  let lf_re = Str.regexp "\r" in
  let check_job j =
    if j#finished then
      false
    else if j#timeouts = !max_timeouts then
      begin
        Printf.printf "%-12s ) * TIMED OUT *\n" j#host;
        flush stdout;
        false
      end
    else
      true
  in
  let post_queue = 
    if read_fds = [] then
      begin
        Printf.printf "waiting for ";
        List.iter (fun x -> Printf.printf "%s " x#host) jobs;
        print_endline "...";
        flush stdout;
        List.map (fun x -> x#timeout) jobs
      end
    else
      let process_job j =
        if List.mem j#pipe read_fds then
          match j#read with
            "" -> j
          | x -> 
              let header = Printf.sprintf "%-12s ) " j#host in
              Printf.printf "%s%s\n"
                header
                (Str.global_replace lf_re ("\r" ^ header) x);
              flush stdout;
              j
        else 
          j
      in
      List.map process_job jobs
  in
  List.filter check_job post_queue

(**
   [runon command hosts] executes command on hosts, printing
   output line by line as it is received.
 *)
let runon command hosts =
  let rec launch jobs queue =
    if Queue.is_empty queue then jobs
    else if List.length jobs = !max_queue then jobs
    else
      let new_job = new Job.job !rsh_user !rsh_cmd command (Queue.pop queue) in
      launch (new_job :: jobs) queue
  in
  let rec iter jobs queue =
    match (jobs, (Queue.length queue)) with
      ([], 0) -> ()
    | _ ->
        let jobs = launch jobs queue in
        iter (run_jobs jobs !timeout) queue
  in
  let hosts_queue = Queue.create () in
  let _ = List.iter (fun x -> Queue.add x hosts_queue) hosts in
  iter [] hosts_queue
    
let usage_message = Printf.sprintf 
    "runon version %s\nusage: runon [options] command hosts" version

let _ = 
  let _ = Arg.parse options (fun x -> args := List.append !args [x]) usage_message in
  let do_usage () = begin Arg.usage options usage_message; exit 1 end in
  match !args with
    [] -> do_usage ()
  | [cmd] -> 
      begin
        ignore (Sys.signal Sys.sigchld Sys.Signal_ignore); (* we don't care about child signals *)
        match !hosts_file with
          None -> do_usage ()
        | Some f -> runon cmd (read_hosts_file f)
      end
  | cmd :: hosts -> 
      runon cmd hosts
