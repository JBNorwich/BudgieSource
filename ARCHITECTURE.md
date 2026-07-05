# Licence for this file
This file is under the Expat licence:

> Copyright 2026 Joseph Baldwin

> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Code style
- Where code reuse is possible in the future, plan for it.
- If you can accomplish the same result in fewer lines of code while keeping it comprehensible, do so.

# Purpose and brief feature description
- This is Budgie Diet, a smart dieting app, intended for weight loss, with weight maintenance and weight gain (i.e. bulking) as lesser but still important use cases.
- The app calculates a calorie budget based on the user's prior activity, taken as their average calories burned over the prior week, and subtracting a deficit (or adding a surplus) to tell them how much they can eat.
- By default, the user is given a "left to eat" figure in a "blob" on the main page. This is intended to tell them how much of their budget they can safely eat while leaving room for a normal evening meal.
- The user is able to log food with simple calorie numbers and narratives to say what they are.
- The user is also able to log and track their hydration/water intake.
- The user is able to see a trend of their weight, and also set a goal weight that they want to reach.

# General design philosophy
- Wherever possible, processing and data storage must be accomplished on-device (which, for the purposes of this app, includes storing the user's data in iCloud via CloudKit, which can be assumed to be private.)
- The use of third party remote APIs is strongly discouraged.
- The HealthKit data sourced by the app must be taken on trust. Do not second-guess HealthKit, save for the rare scenarios where the data is clearly unavailable or so absent or incomplete as to be not useful.
- The user must never need to register an account to use Budgie Diet, or give any contact details or personal information beyond that strictly needed for the app to operate.
- The user must never need to pay.
- The developer must never need to operate or host their own servers or web applications for Budgie Diet to function.
- The user's data must never be sent to or visible by the developer.
- Data input via Budgie Diet should, wherever possible, be exposed to and synced with HealthKit.
- Don't reinvent the wheel. Use standard Apple APIs and structures wherever possible.
- The user's data is sacred. It must be preserved unless they expressly want it deleted.
- Degrade gracefully if HealthKit data isn't available; never block the user.
- Survive multi-device/CloudKit races without destroying data.
- Make use of all the rich affordances offered by Apple's APIs, where these serve the user journey; don't add them for the sake of adding them.

# General UI/UX/design principles
- This app is not for everyone, but it should be approachable to the majority.
- Everything must be, insofar as this is possible, compliant with Apple's UI/UX guidelines.
- In an ideal use case, the user spends as little time in the app as possible, because the information they need is front and centre, and any input is quick and easy.
- Not everyone is completely immersed in health and fitness, or wants to be - but someone using this app is clearly interested in it to some extent.
- The app is not intended to *make* someone obsessed with their health or fitness. Trying to do so is a failure mode; actually doing so may be a safety issue.
- This app is intended for a mass market. Target features, default settings, UX and UI to 90% of the potential user base, with the 10% being offered configuration options to match their needs where proportionate.
- The 1% who need truly esoteric options shouldn't be catered for where this would overly complicate the app or compromise the experience of the 99%.
- Do not expect the user to configure their way out of bad default behaviour.
- The app exists to support the user in whatever goal they choose, subject to the safety principles.
- The app exists to improve the user's health and wellbeing *as they see it*. It is not for the app to judge their goals.
- Adhere to the principle of least astonishment.
- Users' routines are theirs alone. Do not disrupt them.
- Once added, features must be maintained for as long as practicable. Every feature that is released or option presented is one that a user might come to rely upon.
- The user's options and choices must be preserved and respected, both internally and across app versions. Respect their choices with regards to chosen weight/volume/height units.
- The app's failures or shortcomings should not be made into the user's problem. A user's potential unhappiness with the app is most of the time going to be a fault with the app, not the user.
- The same figures displayed in different places must be consistent with each other. Wherever possible, they should be derived from the same place.
- Only offer information that a user might find useful. Do not surface business logic. If it needs to be explained, explain it in clear terms.
- Explain concepts that are non-obvious. Don't explain concepts that are obvious.
- Accessibility is a baseline, not an option.

# Safety principles
- The user's choices are their own. However, this principle should be balanced with the risk that the app could be used in a negative or harmful way.
- Risks must be balanced with the need for the app to be useful as a dieting/calorie budgeting app that most users will use to lose weight in a healthy way.
- The primary risk is of the user developing or reinforcing disordered eating patterns.
- A secondary risk is of the user pursuing a goal that is likely to cause harm.
- A tertiary risk is of the app contributing to or reinforcing body image issues, although this is unlikely with its current feature set.
- The app must not act in any way that would encourage or reinforce disordered eating patterns, or that increase the risk of the user developing them.
- The user's goals and/or their achieving them must not ever be discussed in a context of body image or appearance.
- The app should *attempt to dissuade* the user from making extreme choices that would be harmful to most people, such as a very large 1,000kcal+ deficit or an underweight weight goal.
- The app must *actively prevent* the user from setting goals that are wildly unrealistic or would be harmful in virtually all cases, such as a daily calorie budget below 1,200kcal.
- The user must be told at any point at which the app is refusing to act on their instructions, and signposted to support resources if appropriate.
- The user must not be allowed, at any point, to turn off safeguards.
- Information about the user's budget or activity status must be presented neutrally and without judgment. The user MUST NEVER UNDER ANY CIRCUMSTANCES be directly told to eat more or less food, or do more or less exercise.
- Hard safety limits belong in the model layer, not the UI.
- The user must not be proactively nudged to log food, to check their budget, or to do anything at all. Interaction with Budgie Diet must be entirely unprompted and voluntary.
- The user must not be encouraged or incentivised by way of a deliberate app mechanic to interact with Budgie Diet on a regular basis
    - It is acceptable to warn the user of an absence of data that legitimately prevents a feature from working (e.g. "log your weight for two weeks to see your performance against trend")
- Wording or language must not express disappointment or encourage shame in the user for not logging food, not exercising or otherwise not using the app
    - Similarly, the app must not assume that under-engagement with it is a sign of a disorder (e.g. the user is not logging much food, therefore they are at risk)
- Any wording or language that displays or compares statistics must never make a qualitative, rather than quantitative, judgment of the user's progress
- Any goals that the app allows the user to set must not be based on any aesthetic or body composition considerations (e.g. body size/muscle mass). Weight is exempted purely due to its functional requirement within the app.
- The user must be able to turn off features that surface weight information and not see them at all.
    - It is acceptable for these features to be on by default, or to prompt for the user's weight to calculate their BMI.
- If a feature implementation conflicts with these principles, this should be flagged with a clear rationale for *why* the feature may be problematic.
- While these safety principles are intended, insofar as it is possible, to prevent Budgie Diet from encouraging or reinforcing unhealthy patterns of behaviour, Budgie Diet cannot, and cannot be expected to, prevent harmful decisions on the user's part that are independent of the app. It is not for Budgie Diet to police the user's real world behaviour.

# Forbidden features
In line with the above safety principles, the following are not and never will be implemented in Budgie Diet:

- Push notifications - whether voluntarily set by the user or not
- Any other facility or mechanic that prompts the user to open the app
    - It is acceptable for the user to have a passive widget that displays (e.g.) their current budget, or *allows* them to log food, provided it does not directly encourage them to do so.
- Streaks/awards, points or other "gamification" mechanics
    - It is acceptable to tell the user that they have achieved a goal that they set themselves, e.g. their weight goal, and congratulate them for doing so.
- Suggestions of a goal weight (beyond strongly encouraging the user to not aim to be underweight, and then only if they try to set such a goal)
- Tracking of body measurements such as waist measurements

# Tone of voice/messaging
- Some whimsy is fine (e.g. the optional whale feature, the bird image and phrase at the bottom of BudgetView). Too much is bad and makes the app look unserious.
- Labels for statistics should be brief. Delivering information in sentences should generally be avoided in information-dense environments like BudgetView.
- You can use sentences where appropriate, for example when telling the user about their remaining budget on AddCalsSheet.
- The tone of text should be friendly and approachable, but safety warnings should be delivered clearly and politely.
- Wherever possible, avoid making the user feel bad about their performance. They are allowed to find it *disappointing* if they have gained weight or eaten too much, we shouldn't hide that from them, but the app shouldn't make them feel bad about it.
- Don't overstate risks or be alarmist. NEVER *accuse* the user of trying to do something wrong, or tell them that they have or might have an eating disorder.
- Text should be sensitive to the individuality of users (e.g. someone who wants to gain weight may not be trying to gain muscle, but may be underweight.)
- While the app logo is a bird and the name is Budgie Diet, generally text shouldn't refer to birds or be bird-centric.
- Don't refer to the user by name, or in the first or third person. The user is "you".
- Don't be overfamiliar with the user.
- The user's gender is only collected for the purpose of calculating their body mass index. It must not be surfaced, discussed or used in any other context.
- Where spelling differs between American English and British English, use the British spelling.
- Do not make assumptions about the user's lifestyle, motivations or goals.

# Branding
- The app is called "Budgie Diet", not just "Budgie". Never refer to it as "Budgie" (although this is fine on internal variable names.)
- The app's primary background colour is a blue gradient, as on BudgetView. Other views should be SwiftUI default backgrounds, however.
- The app's logo/icon is a green bird that resembles a budgerigar roughly in the shape of a letter B. On the icon, this is on a blue gradient background.
- Don't overuse the icon or put it in random contexts.

# Data model/inference
- Underlying business logic changes should be strongly resisted, except where they solve clear bugs that would otherwise severely misinform users.
- Do not encourage the user to make inferences that don't exist, or try to connect pieces of information that don't have any real relation.
- Data migration is costly and can be complicated. Avoid using anything but the SwiftData automatic data migration.
