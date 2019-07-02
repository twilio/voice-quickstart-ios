## 4.0 New Features

#### Reconnecting State and Callbacks

`TVOCallStateReconnecting` is provided as a new Call state. A callback `call:isReconnectingWithError:` corresponding to this state transition is triggered when a network change is detected when Call is already in the `TVOCallStateConnected` state. If the Call is in `TVOCallStateConnecting`or in `TVOCallStateRinging` state when network change happened, the SDK will receive the `call:didFailToConnectWithError:` callback with the `TVOErrorConnectionError` error (31005). If a Call is reconnected after reconnection attempts, the application will receive the `callDidReconnect:` callback and the Call state transitions to `TVOCallStateConnected`.

Updates:

```
typedef NS_ENUM(NSUInteger, TVOCallState) {
    TVOCallStateConnecting = 0, ///< The Call is connecting.
    TVOCallStateRinging,        ///< The Call is ringing.
    TVOCallStateConnected,      ///< The Call is connected.
    TVOCallStateReconnecting,   ///< The Call is reconnecting.
    TVOCallStateDisconnected    ///< The Call is disconnected.
};
```

```
@protocol TVOCallDelegate <NSObject>

@optional
- (void)callDidStartRinging:(nonnull TVOCall *)call;
- (void)call:(nonnull TVOCall *)call isReconnectingWithError:(nonnull NSError *)error;

@end
```