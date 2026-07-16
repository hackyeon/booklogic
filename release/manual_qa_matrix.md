# Manual QA Matrix

All initial results are `NOT_RUN`. Codex has not executed real-device QA.

| ID | Category | Platform | Device/OS | Preconditions | Steps | Expected Result | Result | Evidence | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| MQA-001 | Install and launch | Android | Minimum supported Android device | Debug or release QA build installed | Launch app | Home screen appears without crash | NOT_RUN |  |  |
| MQA-002 | Install and launch | Android | Current latest stable Android device | Build installed | Launch app | Home screen appears without crash | NOT_RUN |  |  |
| MQA-003 | Layout | Android | Small 320x568-class screen | Build installed | Play Level 1, 21, 51, 101, 201, 281, 400 | Books, clues, overlays, and settings remain usable | NOT_RUN |  |  |
| MQA-004 | Accessibility | Android | TalkBack enabled | Build installed | Navigate Home, Game, Result, Settings | Controls and game objects have meaningful labels | NOT_RUN |  |  |
| MQA-005 | Display | Android | Large font size | Build installed | Open Home, Game, Tutorial, Settings | No critical overflow; scrollable content remains reachable | NOT_RUN |  |  |
| MQA-006 | Color accessibility | Android | Grayscale or color correction enabled | Build installed | Play representative levels | Books remain distinguishable by symbol and layout | NOT_RUN |  |  |
| MQA-007 | Haptics | Android | Haptic-capable device | Feedback enabled | Select, swap, satisfy clue, clear | Haptics trigger as expected | NOT_RUN |  |  |
| MQA-008 | Haptics | Android | Haptic-limited device | Feedback enabled | Select, swap, clear | App remains usable if haptics are limited | NOT_RUN |  |  |
| MQA-009 | Ads | Android | Debug/Profile test ad device | UMP debug setup available | Clear Level 6 and tap Next | Result overlay appears first, then test interstitial, then next level | NOT_RUN |  | Production ad IDs must not be used. |
| MQA-010 | Network | Android | Airplane mode | Saved progress exists | Launch, play, clear, next level | Puzzle and save flow continue; ad failure does not block | NOT_RUN |  |  |
| MQA-011 | Performance | Android | Low-performance device, Profile mode | Profile build installed | Play Level 281 and Level 400 | No severe frame drops or memory growth observed | NOT_RUN |  |  |
| MQA-012 | Install and launch | iOS | Minimum supported iOS version | Build installed | Launch app | Home screen appears without crash | NOT_RUN |  |  |
| MQA-013 | Install and launch | iOS | Current latest stable iOS version | Build installed | Launch app | Home screen appears without crash | NOT_RUN |  |  |
| MQA-014 | Layout | iOS | Small iPhone screen | Build installed | Play representative levels | Books, clues, overlays, and settings remain usable | NOT_RUN |  |  |
| MQA-015 | Layout | iOS | Large iPhone screen | Build installed | Play Level 281 and Level 400 | Layout remains stable | NOT_RUN |  |  |
| MQA-016 | Device shape | iOS | Notch or Dynamic Island device | Build installed | Navigate Game and Settings | Safe areas are respected | NOT_RUN |  |  |
| MQA-017 | Accessibility | iOS | VoiceOver enabled | Build installed | Navigate Home, Game, Result, Settings | Controls and game objects have meaningful labels | NOT_RUN |  |  |
| MQA-018 | Audio | iOS | Silent mode on and off | Sound enabled | Select, swap, clear | Sound behavior is acceptable for platform mode | NOT_RUN |  |  |
| MQA-019 | Ads | iOS | Debug/Profile test ad device | UMP debug setup available | Clear Level 6 and tap Next | Test interstitial flow returns to game correctly | NOT_RUN |  | Production ad IDs must not be used. |
| MQA-020 | Background/resume | Android/iOS | Build installed | Select book, open tutorial, result overlay, ad loading | Background and resume app | No duplicate events, sounds, tutorial steps, or automatic ad display | NOT_RUN |  |  |
| MQA-021 | Process kill recovery | Android/iOS | Build installed | Trigger progress save and settings save scenarios | Kill and relaunch app | Last committed progress/settings restore without corruption | NOT_RUN |  |  |
| MQA-022 | Store metadata | Google Play/App Store | Console access | Draft listing available | Fill metadata and policy forms | Store answers match release scope and privacy inventory | NOT_RUN |  |  |
