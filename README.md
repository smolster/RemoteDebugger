# RemoteDebugger
This repo contains two implementations of a remote view-state debugger. The debugger system is made up of a client (to be used from an iOS app) and a server (to be used from a macOS app).

The first implementation is a near-copy of the version discussed in this [objc.io](https://objc.io)'s Swift Talk episodes [109](https://talk.objc.io/episodes/S01E109-ios-remote-debugger-connecting-with-bonjour), [110](https://talk.objc.io/episodes/S01E110-ios-remote-debugger-sending-data), and [111](https://talk.objc.io/episodes/S01E111-ios-remote-debugger-receiving-data). This implementation uses the old [Bonjour NetService API](https://developer.apple.com/documentation/foundation/bonjour).

The second implementation is a direct port of the first, but uses [Network.framework](https://developer.apple.com/documentation/network), the new networking API introduced with iOS 12 and macOS Mojave.

The client and server communicate using the [JSON over TCP protocol](https://github.com/turn/json-over-tcp).

## Usage
In your iOS app, create and keep an instance of `RemoteDebuggerClient`, and call `send(newState:action:snapshot)` whenever your state changes.

The initializer of this object takes in a closure that will be called any time the server sends back a new state.

```swift
let remoteDebugger = RemoteDebuggerClient<MyState> { newState in
    // Set app state to newState
}

func stateChanged(to state: MyState, action: String) {
    remoteDebugger.send(newState: state, action: action, snapshot: UIApplication.shared.windows[0])
}
```

In your Mac app, create and keep an instance of `RemoteDebuggerServer`. The initializer of this object takes in a closure that will be called any time the client sends an updated state.

You can call `send(data:)` to send data back to the client.
