NEW
---
* To not route messages through worker_controller
* Specify sources instead of targets like in storm?
* create a hybrid which can be both generating_worker to handle server
  requests and a processing_worker to receive the results (like in
  storm)
* ack messages to make sure all are processed
* Implement multi node/server support

HIGH priority
-------------
* Route messages in worker_controller to workers for
    * Hash on key X or a list of fields (from a record)

MEDIUM priority
---------------
* add checks for unsupported options in config_validator
* restrict the generating_workers if the processing_workers can't cope
  with the load (pull instead of push?)
* Consistent naming of WorkerConfig - CallbackConfig
* handle the simple_one_for_one workers (they do not die in sync with
  its sup)
    * start to use supervisor2 from rabbitmq-server
* improve performance for dynamic workers, a list might not be so good
  for 1000s of workers
* Add new worker_controllers dynamically, to allow for a process
  monitoring a directory for new files, then start a new
  generating_worker for each new file created in that directory. (more
  work to handle processing_worker than generating_worker)
    * Dynamically add/remove targets in a worker_controller
* Make it possible to stop worker_controller:s dynamically
* add possibility for worker to give ets table to worker_controller,
  requires the worker_controller to be passed as an argument in init
* Add possibility to reset all the workers, to start fresh without
  restarting all
* generalize processing_worker to another module to share code with
  generating_worker!
* Give the workers an id, starting from 1, and total worker count?
* Add infinity to all gen_server:calls
* check message queue size, have a way to report it
* remove WorkerMod from worker_controller and make the WorkerMods into
  behavior or at least force then to handle sync events, but what
  about the casting?
* Garbage collect dynamic workers (with empty state)?

LOW priority
------------
* Create a raw event generator which is spawned with a {M,F,A} and then
  it is on its own (possibly supervised via a supervisor_bridge)
* Extract the common code from the sup tests
* Stub processing_worker_sup in worker_controller_tests
* Make the processing_worker and generating_worker behaviour handle
  code_change
* Give the worker the possibility to change the timeout? (at end of
  file?)
