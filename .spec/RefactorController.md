# RefactorController
## REQUIREMENTS

` ``
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



sys {
	if TickDisturbance(selector) {
		<TickDisturbance(selector) -> bool { selector == ON_TICK_DISTURBANCE_SELECTOR}>
		<ON_TICK_DISTURBANCE_SELECTOR = AFTER_SWAP_SELECTOR>
	    Observer(selector,calldata) {
			requirements: [
				"it knows beforehand the size of calldata so it does not have to be passed on"
			],
			sync: [
				tick,
				utilization
			]
		}
	}
	if CmdInput(selector) {
		<CmdInput(selector) -> bool {selector == ON_START_REPLICATION_CMD_SELECTOR}>
		<ON_START_REPLICATION_CMD_SELECTOR = AFTER_ADD_LIQUIDITY_SELECTOR>
		Controller(selector,calldata) {
			...
		}
	}
}

In the context of the underlying control, the sync, settle and notifyDebt is not part of the state as these are integration requirements for the state update of the un derlying stae variable which is sync. This is we do not care about changes on "token  balance", or internal delta accoutning on the pool manager. ALl of this is not part of the protocol semantics. Thus clearing this is an action

> Note the action is shaped by the protocol => Either the action name or action  arg must inglude a reference to the protocol. Since this is pending we do SomeAction(selector,uniswap,calldata)

Then we have 
```
integrations/
	actions.plk
sys/
   sys.plk
   observer.plk
```
MUST be behavioral equivalent to current
```
Controllers/
	Controller.plk
ProtocolSync/
	AlignTickTransition.plk
	AlignTick.plk
	AlignCalldata.plk
is i```	


