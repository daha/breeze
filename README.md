Breeze
======
Breeze is a experiment to make a stream processing app in Erlang.  The
intention is to keep it simple but using Erlang OTP principles with
Erlang applications, supervisors and make use of existing behaviours
and create new ones when it is suitable. The first versions will be
single node without guarantees of processing all events.  There might
be data loss when a worker crashes.

The processing is started ones the master has been configured with a
topology, either by configuring the breeze application with a config
file or by calling breeze_master:set_and_start_configuration/1. The
topology consists of two types of entities, generating workers and
procesing workers, implementing the behaviours breeze_generating_worker
and breeze_processing_worker. The names if these will change as soon
as I find some better names for them. The generating worker emits
Erlang terms from some data source, like a file or twitter stream. The
processing worker gets data from generating workers of other
processing workers and can emit the same or other Erlang terms.

The topology has the following format:
<pre><code>
{Name, WorkerType, BehaviourImplementationModule, NumberOfWorkers, Targets}
Name = atom()
WorkerType = generating_worker | processing_worker
BehaviourImplementationModule = atom()
NumberOfWorkers = integer() | dynamic
Targets = [Target]
Target = {Name, TargetType}
TargetType = all | random | keyhash | dynamic
</code></pre>

Where the name is an atom and must be unique in the
topology. WorkerType is currently generating_worker or
processing_worker. BehaviourImplementationModule is a module
implementing the corresponding behaviour for the
WorkerType. NumberOfWorkers is an positive integer or the atom
dynamic. The Targets is a list of where the worker will emit its
tuples and how the data is distributed.

<dl>
  <dt>all</dt>
  <dd>the term is sent to all workers</dd>

  <dt>random</dt>
  <dd>the term will be sent to a random worker</dd>

  <dt>keyhash</dt>
  <dd>the term must be a tuple, and it be sent to the worker
  corresponding to the hash of the first element of the tuple.</dd>

  <dt>dynamic</dt>
  <dd>the term must be a tuple and the tuple will be sent to the
  worker corresponding to the first element, if it is the first
  message with this specific value of the first element a new worker
  will be started. The number of workers for the target must be
  dynamic.</dd>
</dl>

Below is a example topology where entity "one" is a generating worker
and has 1 worker and it send the emitted terms to all workers of
entity "two". Entity "two" is a processing worker with 2 workers and
it sends its emitted tuples randomly to one of the "three" workers.
Entity "three" is also a processing worker and it has 10 workers.

```erlang
[{breeze,
  [{topology,
    [{one, generating_worker, debug_generating_worker, 1, [{two, all}]},
     {two, processing_worker, debug_processing_worker, 2, [{three, random}]},
     {three, processing_worker, debug_processing_worker, 10, []}]
   }]
 }].
```

Getting started
---------------
```
git clone https://github.com/daha/breeze-examples.git
cd breeze-examples
rebar get-deps clean compile generate
debug_example/rel/breeze_debug_example/bin/breeze_debug_example console -config `pwd`/debug_example/rel/breeze_debug_example/etc/debug
```

Design
------
```
pw - processing worker
gw - generating worker
wc - worker controller

Diagram over the processes:
1-1: one to one
1-N: one to many

                       +-+
                       | | <- breeze_sup
                      1+-+----------------+
                      / |1  1              \
                     /  |                   \
                  1 /   |1                   \1
                 +-+   +-+                    +-+
       wc_sup -> | |   | | worker_supersup    | | master
               1 +-+   +-+                    +-+
                /       |1
               /        |
            N /         |N
           +-+         +-+
     wc -> | |         | | <- worker_sup
           +-+         +-+
                       1|
                        |
                       N|
                       +-+
                       | | <- pw/gw
                       +-+
```
