//
//  Strings.swift
//  Budgie Diet
//
//  Created by Joe Baldwin on 25/08/2024.
//

import Foundation

let whaleSalutations: [String] =
    ["Hi.",
    "Howdy.",
    "Yo.",
    "Splish splash.",
    "Great progress.",
    "I'm a whale."]

let healthDisclaimer: String = "**IMPORTANT:** Budgie Diet is for information purposes only, and its suggestions are not a substitute for professional medical advice. It's best to consult your doctor before starting any new diet plan."

let weightingText = "This adjusts how predicted active calories are weighted. Most people should stick with the default, but you can change it if you feel your budgets are often too high or low.\n\n**Forgiving:** Budgie Diet more strongly adjusts its predictions in the late evening and continues predicting until midnight, while making no adjustments to your average. This works well if you usually exercise in the evening, but it might make your budget higher than it should be otherwise.\n\n**Default:** This balanced setting gradually adjusts predictions from morning to 10pm, when it stops predicting new calories, and downweights your average by 25%. Most people will find this setting ideal.\n\n**Harsh:** This setting adjusts your budget down very harshly, and continues linearly throughout the day until 10pm. This is ideal for people who either exercise in the early morning or not at all, but will significantly reduce your budget otherwise.\n\n**No predictions at all:** Budgie Diet won’t estimate active calories for you. Your budget will only include resting calories and any exercise you’ve done. It’ll be very accurate, but might feel a bit restrictive, especially in the morning."

let cappingText = "This lets you cap your budget, so even if you exercise more than expected, your budget will not exceed this amount (i.e. Budgie Diet will not prompt you to \"eat back\" all the calories you've burned over your averages).\n\n**WARNING:** **Diets based on extreme caloric restriction and/or extreme levels of exercise are both unsustainable and unhealthy, and carry serious health risks.** Budgie Diet is also hard-coded to never allow your budget to dip below 1,200kcal per day under any circumstances.\n\nBudgie Diet is for information purposes only, and its suggestions are not a substitute for professional medical advice. Its developer strongly encourages you to discuss any diet plans with a reputable medical professional first, especially if these would involve you eating less than 1,200kcal per day."
