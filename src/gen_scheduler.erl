-module (gen_scheduler).

-export([init/3,
        start/0,
        join/0,
        abort/0,
        stop/1,
        declineOffer/1,
        declineOffer/2,
        killTask/1,
        reviveOffers/0,
        sendFrameworkMessage/3,
        requestResources/1,
        reconcileTasks/1,
        launchTasks/2,
        launchTasks/3,
        destroy/0]).

-export([behaviour_info/1]).

% private
-export ([loop/1]).

-include_lib("include/mesos.hrl").

behaviour_info(callbacks) ->
    [ {registered, 2 }, 
      {reregistered, 1 }, 
      {disconnected, 0 }, 
      {offerRescinded, 1 }, 
      {statusUpdate, 1 }, 
      {frameworkMessage, 3 }, 
      {slaveLost, 1 }, 
      {executorLost, 3 } , 
      {error, 1 }, 
      {resourceOffers,1 }];
behaviour_info(_Other) ->
    undefined.

init(Module, FrameworkInfo, MasterLocation) when is_record(FrameworkInfo, 'FrameworkInfo'), 
                                                 is_list(MasterLocation) ->
    Pid = spawn(?MODULE, loop, [Module]),
    Result = scheduler:init(Pid, FrameworkInfo, MasterLocation),
    Result.

start() ->
    scheduler:start().
join() ->
    scheduler:join().
abort() ->
    scheduler:abort().
stop(Failover) ->
    scheduler:stop(Failover).
declineOffer(OfferId)->
    scheduler:declineOffer(OfferId).  
declineOffer(OfferId,Filter) ->
    scheduler:declineOffer(OfferId,Filter).
killTask(TaskId)->
    scheduler:killTask(TaskId).
reviveOffers()->
    scheduler:reviveOffers().
sendFrameworkMessage(ExecuterId,SlaveId,Data) ->
    scheduler:sendFrameworkMessage(ExecuterId,SlaveId,Data).
requestResources(Requests)->
    scheduler:requestResources(Requests).
reconcileTasks(TaskStatus)->
    scheduler:reconcileTasks(TaskStatus).
launchTasks(OfferId, TaskInfos)->
    scheduler:launchTasks(OfferId, TaskInfos).
launchTasks(OfferId, TaskInfos, Filter)->
    scheduler:launchTasks(OfferId, TaskInfos, Filter).
destroy()->
    scheduler:destroy().

% main call back loop
loop(Module) -> 
    receive     
        {registered , FrameworkIdBin, MasterInfoBin } ->            
                FrameworkId = mesos_pb:decode_msg(FrameworkIdBin, 'FrameworkID'),
                MasterInfo = mesos_pb:decode_msg(MasterInfoBin, 'MasterInfo'),
                MasterInfo2 = MasterInfo#'MasterInfo'{ip = int_to_ip(MasterInfo#'MasterInfo'.ip)},
                Module:registered(FrameworkId, MasterInfo2),
                loop(Module);
        {resourceOffers, OfferBin} ->
                Offer = mesos_pb:decode_msg(OfferBin, 'Offer'),
                Module:resourceOffers(Offer),
                loop(Module);
        {reregistered} ->
                Module:reregistered(),
                loop(Module);
        {disconnected} ->
                Module:disconnected(),
                loop(Module);   
        {offerRescinded, OfferIdBin} ->
                OfferId = mesos_pb:decode_msg(OfferIdBin, 'OfferID'),
                Module:offerRescinded(OfferId),
                loop(Module);
        {statusUpdate, TaskStatusBin} ->
                TaskStatus = mesos_pb:decode_msg(TaskStatusBin, 'TaskStatus'),
                Module:statusUpdate(TaskStatus),
                loop(Module);
        {frameworkMessage, ExecutorIdBin, SlaveIdBin, Message} ->
                ExecutorId = mesos_pb:decode_msg(ExecutorIdBin, 'ExecutorID'),
                SlaveId = mesos_pb:decode_msg(SlaveIdBin, 'SlaveID'),
                Module:frameworkMessage(ExecutorId,SlaveId,Message),
                loop(Module);
        {slaveLost, SlaveIdBin} ->
                SlaveId = mesos_pb:decode_msg(SlaveIdBin, 'SlaveID'),
                Module:frameworkMessage(SlaveId),
                loop(Module);
        {executorLost, ExecutorIdBin, SlaveIdBin, Status} ->
                ExecutorId = mesos_pb:decode_msg(ExecutorIdBin, 'ExecutorID'),
                SlaveId = mesos_pb:decode_msg(SlaveIdBin, 'SlaveID'),
                Module:executorLost(ExecutorId,SlaveId,Status),
                loop(Module);
        {error, Message} ->
                Module:error(Message),
                loop(Module);           
        Any ->
            io:format("other message from nif : ~p~n", [Any]),
            loop(Module)
    after
        1000 ->
            loop(Module)
    end.

% helpers
int_to_ip(Ip)-> {Ip bsr 24, (Ip band 16711680) bsr 16, (Ip band 65280) bsr 8, Ip band 255}.
