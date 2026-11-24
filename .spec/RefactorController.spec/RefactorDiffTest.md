
```
integrations/
	actions.plk
sys/
   sys.plk
   Observer.plk
   Controller.plk
```
MUST be behavioral equivalent to current
```
Controllers/
	Controller.plk
ProtocolSync/
	AlignTickTransition.plk
	AlignTick.plk
	AlignCalldata.plk
```	


- We need to trace the behaviors of each of those modules on the tests.

Current

test/
	ProtocolSync/
		AlignTick.t.sol 

IControllerSetter -> ISys
	setController ---> setSys

New

test/
	sys/
		Observer.t.sol
	
