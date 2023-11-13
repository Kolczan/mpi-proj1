% --------------- INPUTS ---------------

% Number of servers
int: serverCount;
constraint serverCount > 0;

% Number of virtualized resources
int: virtualizedServiceCount;
constraint virtualizedServiceCount > 0;

% Virtualized service 
array[servers, virtualizedServices] of var int: virtualizedServiceResourceUsages;
constraint forall (s in servers) (
  forall (v in virtualizedServices) (
    virtualizedServiceResourceUsages[s, v] >= 0
  )
);

% Server capacity
array[servers] of var int: serverCapacities;
constraint forall (s in servers) (serverCapacities[s] > 0);

% Allocation costs
array[servers, virtualizedServices] of var int: allocationCosts;
constraint forall (s in servers) (
  forall (v in virtualizedServices) (
    allocationCosts[s, v] >= 0
  )
);

% Intensity of request flow
int: lambda;
constraint lambda > 0;

% Required availability of the services allocated on the nodes
float: sla;
constraint sla > 0.0;

% Possible request types
int: requestTypeCount;
constraint requestTypeCount > 0;

% Request sizes
array[requestTypes] of var int: requestTypeSizes;


% ----------- INFERRED DATA ------------

% Discrete time
set of int: time = 1..1000;

% Servers
set of int: servers = 1..serverCount;

% Virtualized resources
set of int: virtualizedServices = 1..virtualizedServiceCount;

% Types of requests
set of int: requestTypes = 1..requestTypeCount;

% Requests
array[servers, time] of var int: requests = array2d(servers, time, [ poisson(lambda) | s in servers, t in time ]);
array[servers] of var int: maxRequests = [ max(requests[s, time]) | s in servers ];

% Required capacity
array[servers] of var float: requiredAllocations = [ sla * maxRequests[s] | s in servers ];


% ------------ OPTIMIZE FOR ------------

% Allocate each service to one server exactly
array[servers, virtualizedServices] of var 0..1: resourceAllocations;
constraint forall (v in virtualizedServices) (
  sum (s in servers) 
    (resourceAllocations[s, v]) == 1
);

% Do not exceed available capacity and that SLA is upheld
constraint forall (s in servers) (
  sum (v in virtualizedServices) 
    (virtualizedServiceResourceUsages[s, v] * resourceAllocations[s, v]) <= serverCapacities[s]
  /\
  sum (v in virtualizedServices)
    (virtualizedServiceResourceUsages[s, v] * resourceAllocations[s, v]) >= requiredAllocations[s]
);

% Cost-adjusted allocations
array[servers, virtualizedServices] of var int: costAdjustedAllocations;
constraint forall (s in servers, v in virtualizedServices)
  (costAdjustedAllocations[s, v] = allocationCosts[s, v] * resourceAllocations[s, v]);

% Find the cheapest allocations
solve minimize sum (s in servers, v in virtualizedServices)
  (allocationCosts[s, v] * resourceAllocations[s, v]);

output
  [ "resource allocations =\n" ++ show2d(resourceAllocations) ++ "\n\n" ];

output
  [ "costs of allocation =\n" ++ show2d(allocationCosts) ++ "\n\n" ];

output
  [ "actual allocation costs =\n" ++ show2d(costAdjustedAllocations) ++ "\n\n" ];

output
  [ "resource usage [\(s)] = \(sum (v in virtualizedServices) (virtualizedServiceResourceUsages[s, v] * resourceAllocations[s, v])) / \(serverCapacities[s])\n" | s in servers ];
 
output
  [ "\n" ];

output
  [ "SLA: \(sla * 100.0)%\n" ];

output
  [ "maximum flow and SLA-required resources [\(s)] = \(maxRequests[s]) / \(requiredAllocations[s])\n" | s in servers ];
 
output
  [ "\n" ];
  
output
  [ "total allocation cost = \(sum (s in servers, v in virtualizedServices) (allocationCosts[s, v] * resourceAllocations[s, v]))\n" ];
