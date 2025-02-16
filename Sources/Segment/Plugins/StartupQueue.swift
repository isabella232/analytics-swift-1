//
//  StartupQueue.swift
//  Segment
//
//  Created by Brandon Sneed on 6/4/21.
//

import Foundation
import Sovran

internal class StartupQueue: Plugin, Subscriber {
    static let maxSize = 1000

    @Atomic var running: Bool = false
    
    let type: PluginType = .before
    
    var analytics: Analytics? = nil {
        didSet {
            analytics?.store.subscribe(self, handler: runningUpdate)
        }
    }
    
    let syncQueue = DispatchQueue(label: "startupQueue.segment.com")
    var queuedEvents = [RawEvent]()
    
    required init() { }
    
    func execute<T: RawEvent>(event: T?) -> T? {
        if running == false, let e = event  {
            // timeline hasn't started, so queue it up.
            syncQueue.sync {
                if queuedEvents.count >= Self.maxSize {
                    // if we've exceeded the max queue size start dropping events
                    queuedEvents.removeFirst()
                }
                queuedEvents.append(e)
            }
            return nil
        }
        // the timeline has started, so let the event pass.
        return event
    }
}

extension StartupQueue {
    internal func runningUpdate(state: System) {
        running = state.running
        if state.running {
            replayEvents()
        }
    }
    
    internal func replayEvents() {
        // replay the queued events to the instance of Analytics we're working with.
        syncQueue.sync {
            for event in queuedEvents {
                analytics?.process(event: event)
            }
            queuedEvents.removeAll()
        }
    }
}
