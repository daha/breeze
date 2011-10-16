EMP
===
EMP is a experiment to make a stream processing app in erlang.  The
intention is to keep it simple but using erlang OTP principles with
erlang applications, supervisors and make use of existing behaviours
and create new ones when it is suitable. The first versions will be
single node without guarantees of processing all events.  There might
be data loss when a worker crashes.

Design
------
epa - event processing app
epw - event processing worker
epc - event processing controller

Diagram over the processes:
1-1: one to one
1-N: one to many

                       +-+
                       | | <- epa_sup
                     1 +-+
                      / |1
                     /  |
                  1 /   |1
                 +-+   +-+
      epc_sup -> | |   | | pc_supersup
               1 +-+   +-+
                /       |1
               /        |
            N /         |N
           +-+         +-+
    epc -> | |         | | <- pc_sup
           +-+         +-+
                       1|
                        |
                       N|
                       +-+
                       | | <- epw
                       +-+
