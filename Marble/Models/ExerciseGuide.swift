import Foundation

/// Static "how to perform" content for the exercise library, shown on the
/// About tab of the exercise guide popup. Keyed by exercise name, matching
/// `ExerciseSeed.exercises` exactly.
///
/// Instructions and the demonstration illustrations are sourced from
/// simplyfitness.com's public exercise guides and rewritten into short
/// plain-language steps. Five movements not covered there (Arnold Press,
/// Face Pull, Russian Twist, Decline Sit Up, Ab Wheel Rollout) are written
/// from scratch and have no illustration (`imageName == nil`).
struct ExerciseGuide {
    let summary: String
    let primaryMuscles: String
    /// Empty when the movement has no notable secondary movers.
    let secondaryMuscles: String
    let steps: [String]
    /// Asset-catalog name of the demonstration illustration, or nil when
    /// none exists for this movement.
    let imageName: String?
}

enum ExerciseGuides {
    /// Returns the guide for an exercise by name, or nil for custom
    /// exercises (and the handful of stock ones without written content).
    static func guide(for name: String) -> ExerciseGuide? { all[name] }

    static let all: [String: ExerciseGuide] = [
        // MARK: Chest
        "Bench Press": ExerciseGuide(
            summary: "A compound barbell press done lying on a flat bench to build the chest, shoulders, and triceps.",
            primaryMuscles: "Chest",
            secondaryMuscles: "Front delts, Triceps",
            steps: [
                "Lie on the bench with your feet flat on the floor.",
                "Grip the bar a bit wider than shoulder width.",
                "Unhook the bar and lower it slowly to your lower chest.",
                "Press the bar up until your arms are nearly straight.",
                "Keep elbows pointed out and shoulders flat on the bench.",
            ],
            imageName: "guide-bench-press"
        ),
        "Incline Bench Press": ExerciseGuide(
            summary: "An incline barbell press that targets the upper chest while working the shoulders and triceps.",
            primaryMuscles: "Upper chest",
            secondaryMuscles: "Front delts, Triceps",
            steps: [
                "Lie back on the incline bench with feet flat on the floor.",
                "Grip the bar a bit wider than shoulder width.",
                "Unhook the bar and lower it slowly to your upper chest.",
                "Press the bar up until your arms are nearly straight.",
                "Keep elbows out and shoulders flat against the bench.",
            ],
            imageName: "guide-incline-bench-press"
        ),
        "Dumbbell Fly": ExerciseGuide(
            summary: "A chest isolation move that opens and closes the arms in an arc to stretch and squeeze the pecs.",
            primaryMuscles: "Chest",
            secondaryMuscles: "Front delts",
            steps: [
                "Lie on the bench holding a dumbbell in each hand above your chest.",
                "Use a neutral grip with palms facing each other.",
                "Lower the weights out in a wide arc until your chest stretches.",
                "Stop at shoulder level, then arc them back up together.",
                "Keep elbows slightly bent and shoulders flat throughout.",
            ],
            imageName: "guide-dumbbell-fly"
        ),
        "Cable Fly": ExerciseGuide(
            summary: "A standing cable move that draws the arms together in an arc to isolate and squeeze the chest.",
            primaryMuscles: "Chest",
            secondaryMuscles: "Front delts",
            steps: [
                "Stand in the middle between the pulleys, holding a handle in each hand.",
                "Lean your chest slightly forward with elbows slightly bent.",
                "Draw your hands together in front of your chest in an arc.",
                "Squeeze your chest and pause when your hands meet.",
                "Slowly return along the same arc to the start.",
            ],
            imageName: "guide-cable-fly"
        ),
        "Chest Press": ExerciseGuide(
            summary: "A seated machine press that builds the chest with help from the triceps and shoulders.",
            primaryMuscles: "Chest",
            secondaryMuscles: "Triceps, Front delts",
            steps: [
                "Set the seat so the handles line up with your lower chest.",
                "Sit back fully with your head against the headrest.",
                "Grab a handle in each hand and push your chest out.",
                "Press the handles forward until your arms are nearly straight.",
                "Pause before lockout, then slowly return to the start.",
            ],
            imageName: "guide-chest-press"
        ),
        "Dip": ExerciseGuide(
            summary: "A bodyweight push on parallel bars that mainly trains the triceps with the lower chest and shoulders.",
            primaryMuscles: "Triceps",
            secondaryMuscles: "Front delts, Lower chest",
            steps: [
                "Grip the parallel bars with arms straight and body hanging.",
                "Bend your knees and let your legs hang behind you.",
                "Keep elbows tucked in as you slowly lower down.",
                "Stop when your elbows reach about a 90-degree angle.",
                "Press back up and squeeze your triceps at the top.",
            ],
            imageName: "guide-dip"
        ),
        "Push Up": ExerciseGuide(
            summary: "A bodyweight floor exercise that trains the chest along with the shoulders, triceps, and biceps.",
            primaryMuscles: "Chest",
            secondaryMuscles: "Front delts, Triceps",
            steps: [
                "Lie face down with hands wide and level with your chest.",
                "Stretch your legs out and look toward the floor.",
                "Slowly bend your arms to lower your chest down.",
                "Stop when your elbows reach about a 90-degree angle.",
                "Push through your hands back to the starting position.",
            ],
            imageName: "guide-push-up"
        ),

        // MARK: Shoulders
        "Overhead Press": ExerciseGuide(
            summary: "A standing barbell press that builds shoulder strength and overall pressing power.",
            primaryMuscles: "Delts",
            secondaryMuscles: "Triceps",
            steps: [
                "Stand tall, feet shoulder-width apart, knees slightly bent, chest up.",
                "Hold the bar at chin level with an overhand grip.",
                "Press the bar straight up until your arms are nearly straight.",
                "Lower the bar slowly back to chin level.",
            ],
            imageName: "guide-overhead-press"
        ),
        "Dumbbell Shoulder Press": ExerciseGuide(
            summary: "A seated dumbbell press that strengthens the shoulders and triceps.",
            primaryMuscles: "Delts",
            secondaryMuscles: "Triceps",
            steps: [
                "Sit on a bench with your back supported against the backrest.",
                "Hold dumbbells just above shoulder height, palms facing forward.",
                "Push the dumbbells straight up until your arms are fully extended.",
                "Lower them slowly back to shoulder height.",
            ],
            imageName: "guide-dumbbell-shoulder-press"
        ),
        "Arnold Press": ExerciseGuide(
            summary: "A rotating dumbbell shoulder press that works all three heads of the deltoid.",
            primaryMuscles: "Delts",
            secondaryMuscles: "Triceps",
            steps: [
                "Sit tall holding dumbbells at chest height, palms facing you.",
                "Press up while rotating your palms to face forward.",
                "Finish with arms extended overhead and palms forward.",
                "Lower and rotate back to the starting position.",
            ],
            imageName: nil
        ),
        "Lateral Raise": ExerciseGuide(
            summary: "A dumbbell raise that isolates and builds the side of the shoulders.",
            primaryMuscles: "Side delts",
            secondaryMuscles: "Traps",
            steps: [
                "Stand with feet shoulder-width apart, a dumbbell in each hand.",
                "Keep your elbows slightly bent throughout the movement.",
                "Slowly raise your arms out to the sides until level with shoulders.",
                "Pause briefly at the top, then lower slowly.",
            ],
            imageName: "guide-lateral-raise"
        ),
        "Rear Delt Fly": ExerciseGuide(
            summary: "A fly that targets the rear shoulders for better posture and balance.",
            primaryMuscles: "Rear delts",
            secondaryMuscles: "Traps",
            steps: [
                "Stand between the pulleys, holding each handle with the opposite hand.",
                "Start with your arms crossed in front at shoulder height.",
                "Keep arms nearly straight and pull your elbows back in an arc.",
                "Squeeze your rear shoulders, then return slowly to the start.",
            ],
            imageName: "guide-rear-delt-fly"
        ),
        "Face Pull": ExerciseGuide(
            summary: "A cable pull toward the face that strengthens rear delts and upper back.",
            primaryMuscles: "Rear delts",
            secondaryMuscles: "Traps, Rhomboids",
            steps: [
                "Set a rope on a cable pulley at upper-chest height.",
                "Grab the rope ends, palms facing in, and step back.",
                "Pull the rope toward your face, flaring elbows out wide.",
                "Squeeze your shoulder blades, then return slowly.",
            ],
            imageName: nil
        ),
        "Shrug": ExerciseGuide(
            summary: "A dumbbell shrug that builds the upper trapezius muscles of the neck and shoulders.",
            primaryMuscles: "Traps",
            secondaryMuscles: "",
            steps: [
                "Stand tall with a dumbbell in each hand, arms straight.",
                "Keep your arms straight and raise your shoulders as high as possible.",
                "Squeeze your traps at the top of the movement.",
                "Lower your shoulders slowly back down.",
            ],
            imageName: "guide-shrug"
        ),

        // MARK: Back
        "Deadlift": ExerciseGuide(
            summary: "A full-body barbell lift where you stand up with a bar from the floor, building the back and legs.",
            primaryMuscles: "Back, Legs",
            secondaryMuscles: "",
            steps: [
                "Stand with feet near shoulder-width, the bar over your midfoot.",
                "Bend your knees and grip the bar just outside your legs.",
                "Keep your back flat, chest up, and shoulders pulled back.",
                "Push through your legs and stand up straight, keeping arms straight.",
                "Lower the bar back down slowly without rounding your back.",
            ],
            imageName: "guide-deadlift"
        ),
        "Pull Up": ExerciseGuide(
            summary: "A bodyweight pull where you hang and lift your chin over a bar, training the back and biceps.",
            primaryMuscles: "Back",
            secondaryMuscles: "Biceps",
            steps: [
                "Grab the bar with palms facing away, hands wider than shoulders.",
                "Hang with elbows slightly bent and head looking slightly up.",
                "Pull your chin up toward the bar.",
                "Lower yourself down slowly to a full hang.",
            ],
            imageName: "guide-pull-up"
        ),
        "Chin Up": ExerciseGuide(
            summary: "A bodyweight pull using an underhand grip to raise your chin over the bar, working the back and biceps.",
            primaryMuscles: "Back",
            secondaryMuscles: "Biceps",
            steps: [
                "Grab the bar with palms facing you, hands about shoulder-width apart.",
                "Hang with elbows slightly bent, pointing forward, head slightly up.",
                "Pull your chin up toward the bar.",
                "Lower yourself down slowly to a full hang.",
            ],
            imageName: "guide-chin-up"
        ),
        "Barbell Row": ExerciseGuide(
            summary: "A bent-over barbell pull toward your stomach that builds the back, rear shoulders, and biceps.",
            primaryMuscles: "Back",
            secondaryMuscles: "Rear delts, Biceps",
            steps: [
                "Stand with knees slightly bent and hinge forward at the hips.",
                "Grip the bar wider than shoulders, keeping your back straight.",
                "Pull the bar toward your stomach, squeezing your shoulders and elbows back.",
                "Lower the bar back down slowly under control.",
            ],
            imageName: "guide-barbell-row"
        ),
        "Single-Arm Dumbbell Row": ExerciseGuide(
            summary: "A one-arm dumbbell pull braced on a bench that targets the back, rear shoulders, and biceps.",
            primaryMuscles: "Back",
            secondaryMuscles: "Rear delts, Biceps",
            steps: [
                "Place one knee and the same-side hand on a bench.",
                "Keep your other foot on the floor and chest parallel to the ground.",
                "Grab the dumbbell with a neutral grip, palm facing in.",
                "Lift it by raising your elbow, keeping your arm close to your body.",
                "Lower the dumbbell back down slowly, then switch sides.",
            ],
            imageName: "guide-single-arm-dumbbell-row"
        ),
        "Lat Pulldown": ExerciseGuide(
            summary: "A seated cable pull that brings a wide bar to your chin, building the lats and biceps.",
            primaryMuscles: "Back",
            secondaryMuscles: "Biceps",
            steps: [
                "Sit with your thighs secured under the padded supports.",
                "Grab the bar with palms facing away, hands wider than shoulders.",
                "Pull the bar down to your chin, keeping elbows out.",
                "Squeeze briefly, then let the bar rise back up slowly.",
            ],
            imageName: "guide-lat-pulldown"
        ),
        "Cable Row": ExerciseGuide(
            summary: "A seated cable pull toward your stomach that trains the back, rear shoulders, and biceps.",
            primaryMuscles: "Back",
            secondaryMuscles: "Rear delts, Biceps",
            steps: [
                "Sit on the bench with feet on the foot plate.",
                "Grab the handle with both hands, back straight and knees slightly bent.",
                "Pull the handle toward your stomach, driving your elbows far back.",
                "Return slowly to the starting position under control.",
            ],
            imageName: "guide-cable-row"
        ),
        "Seated Machine Row": ExerciseGuide(
            summary: "A seated machine pull with your chest on the pad that builds the back, rear shoulders, and biceps.",
            primaryMuscles: "Back",
            secondaryMuscles: "Rear delts, Biceps",
            steps: [
                "Sit with your chest resting against the support pad.",
                "Grab the machine handles, keeping your back straight.",
                "Pull the handles toward you, driving your elbows as far back as possible.",
                "Squeeze your back briefly at the end of the pull.",
                "Return slowly to the starting position under control.",
            ],
            imageName: "guide-seated-machine-row"
        ),

        // MARK: Legs
        "Squat": ExerciseGuide(
            summary: "A barbell lower-body exercise that builds strength in the thighs and glutes.",
            primaryMuscles: "Quads, Glutes",
            secondaryMuscles: "Core, Lower back",
            steps: [
                "Stand with the bar resting across your upper back and shoulders.",
                "Grip the bar firmly and keep your head facing forward.",
                "Bend your knees and push your hips back like sitting down.",
                "Keep your back straight as your chest leans slightly forward.",
                "Stop when thighs are parallel, then stand back up.",
            ],
            imageName: "guide-squat"
        ),
        "Leg Press": ExerciseGuide(
            summary: "A machine press that strengthens the thighs and glutes while seated.",
            primaryMuscles: "Quads, Glutes",
            secondaryMuscles: "",
            steps: [
                "Sit on the bench with feet flat, shoulder-width apart on the platform.",
                "Release the safety catch and slowly lower the load.",
                "Bend until your knees reach a 90-degree angle, then pause.",
                "Slowly press back up, stopping just before legs lock out.",
                "Keep your buttocks down on the bench throughout.",
            ],
            imageName: "guide-leg-press"
        ),
        "Hack Squat": ExerciseGuide(
            summary: "A machine squat that targets the thighs and glutes with back support.",
            primaryMuscles: "Quads, Glutes",
            secondaryMuscles: "",
            steps: [
                "Stand in the machine with shoulders under the pads, feet shoulder-width.",
                "Release the safety catch and slowly bend your knees.",
                "Lower until your knees reach a 90-degree angle, then pause.",
                "Slowly press up, stopping just before your legs lock out.",
                "Keep your back firmly against the backrest the whole time.",
            ],
            imageName: "guide-hack-squat"
        ),
        "Leg Extension": ExerciseGuide(
            summary: "A seated machine exercise that isolates and strengthens the quadriceps.",
            primaryMuscles: "Quads",
            secondaryMuscles: "",
            steps: [
                "Sit with knees at the bench edge and ankles below the footrest.",
                "Keep your back firm against the backrest and hold the side handles.",
                "Straighten your legs until they are fully extended.",
                "Squeeze your quads briefly at the top.",
                "Slowly lower back to the starting position.",
            ],
            imageName: "guide-leg-extension"
        ),
        "Leg Curl": ExerciseGuide(
            summary: "A lying machine exercise that targets the hamstrings.",
            primaryMuscles: "Hamstrings",
            secondaryMuscles: "Calves",
            steps: [
                "Lie face-down with the back of your ankles against the footrest.",
                "Grasp the handles and press firmly into the bench.",
                "Bend your legs, curling your heels as far as possible.",
                "Squeeze your hamstrings briefly at the top.",
                "Slowly lower back down to the start.",
            ],
            imageName: "guide-leg-curl"
        ),
        "Romanian Deadlift": ExerciseGuide(
            summary: "A barbell hip-hinge that strengthens the hamstrings, glutes, and lower back.",
            primaryMuscles: "Hamstrings, Glutes",
            secondaryMuscles: "Lower back",
            steps: [
                "Stand with feet shoulder-width, toes forward, knees slightly bent.",
                "Hold the barbell at your upper thighs with an overhand grip.",
                "Keep legs stiff and hinge forward, lowering the bar down.",
                "Pause when you feel your hamstrings tighten.",
                "Return up, keeping your back straight and shoulders back.",
            ],
            imageName: "guide-romanian-deadlift"
        ),
        "Calf Raise": ExerciseGuide(
            summary: "A standing machine exercise that strengthens the calves.",
            primaryMuscles: "Calves",
            secondaryMuscles: "",
            steps: [
                "Stand with the balls of your feet on the wedge.",
                "Place your shoulders under the padded supports.",
                "Raise your heels as high as possible by squeezing your calves.",
                "Hold briefly at the top, feeling the contraction.",
                "Slowly lower your heels to stretch the calves.",
            ],
            imageName: "guide-calf-raise"
        ),
        "Hip Thrust": ExerciseGuide(
            summary: "A barbell exercise that builds the glutes and thighs by extending the hips.",
            primaryMuscles: "Glutes, Quads",
            secondaryMuscles: "Core",
            steps: [
                "Sit on the floor with your upper back against a bench.",
                "Position the bar across your hips, feet flat and shoulder-width.",
                "Drive through your feet and push your hips upward.",
                "Squeeze your glutes until your body is level like a tabletop.",
                "Pause, then lower your hips back down with control.",
            ],
            imageName: "guide-hip-thrust"
        ),
        "Lunge": ExerciseGuide(
            summary: "A dumbbell exercise that strengthens the glutes and thigh muscles one leg at a time.",
            primaryMuscles: "Glutes, Quads",
            secondaryMuscles: "",
            steps: [
                "Stand with legs hip-width apart, holding a dumbbell in each hand.",
                "Keep your upper body straight and take a step forward.",
                "Slowly lower until your front thigh is parallel to the ground.",
                "Push back up to the starting position.",
                "Repeat, then switch to the other leg.",
            ],
            imageName: "guide-lunge"
        ),
        "Bulgarian Split Squat": ExerciseGuide(
            summary: "A single-leg squat with the rear foot raised that targets the thighs and glutes.",
            primaryMuscles: "Glutes, Quads",
            secondaryMuscles: "Core, Calves",
            steps: [
                "Hold a dumbbell in each hand and stand in front of a bench.",
                "Rest one foot on the bench behind you, laces down.",
                "Place your front foot about three steps ahead of the bench.",
                "Squat down on your front leg until your back knee nearly touches.",
                "Push up through your front foot to return to the start.",
            ],
            imageName: "guide-bulgarian-split-squat"
        ),
        "Hip Abduction": ExerciseGuide(
            summary: "A seated machine exercise that strengthens the outer hips and glutes.",
            primaryMuscles: "Hip abductors",
            secondaryMuscles: "Glutes",
            steps: [
                "Sit with your knees inside and against the pads.",
                "Pull the pin to release the pads and grasp the side handles.",
                "Push your knees outward against the pads.",
                "Pause when your hips are fully spread apart.",
                "Slowly return to the starting position.",
            ],
            imageName: "guide-hip-abduction"
        ),

        // MARK: Arms
        "Bicep Curl": ExerciseGuide(
            summary: "An alternating dumbbell curl that builds the biceps by curling one arm at a time.",
            primaryMuscles: "Biceps",
            secondaryMuscles: "",
            steps: [
                "Stand tall with knees slightly bent and back straight.",
                "Hold a dumbbell in each hand, palms facing your body.",
                "Curl one arm up, rotating your palm to face upward.",
                "Squeeze your biceps, then lower slowly under control.",
                "Keep elbows tucked in and alternate arms.",
            ],
            imageName: "guide-bicep-curl"
        ),
        "Hammer Curl": ExerciseGuide(
            summary: "A dumbbell curl with palms facing in that strengthens the biceps and forearms.",
            primaryMuscles: "Biceps",
            secondaryMuscles: "Forearms",
            steps: [
                "Stand tall with knees slightly bent and back straight.",
                "Hold a dumbbell in each hand, palms facing your body.",
                "Curl one arm up while keeping your palm facing inward.",
                "Squeeze your biceps, then lower slowly under control.",
                "Keep elbows close to your body and alternate arms.",
            ],
            imageName: "guide-hammer-curl"
        ),
        "Preacher Curl": ExerciseGuide(
            summary: "A supported EZ-bar curl on a preacher bench that isolates the biceps.",
            primaryMuscles: "Biceps",
            secondaryMuscles: "",
            steps: [
                "Set the armrest just below shoulder height and sit down.",
                "Rest your upper arms on the pad, palms facing up.",
                "Grip the EZ bar and curl it toward your shoulders.",
                "Squeeze your biceps at the top of the lift.",
                "Lower slowly, keeping a slight bend to protect your elbows.",
            ],
            imageName: "guide-preacher-curl"
        ),
        "Tricep Pushdown": ExerciseGuide(
            summary: "A cable pushdown that targets the triceps by straightening the arms against resistance.",
            primaryMuscles: "Triceps",
            secondaryMuscles: "",
            steps: [
                "Face the cable machine and grip the bar with palms down.",
                "Set your hands about shoulder-width apart.",
                "Push the bar down until your arms are fully straight.",
                "Squeeze your triceps briefly at the bottom.",
                "Keep elbows close to your body and return slowly.",
            ],
            imageName: "guide-tricep-pushdown"
        ),
        "Overhead Tricep Extension": ExerciseGuide(
            summary: "A seated overhead dumbbell extension that stretches and works the triceps.",
            primaryMuscles: "Triceps",
            secondaryMuscles: "",
            steps: [
                "Sit on a bench with your back straight.",
                "Hold one dumbbell overhead with both hands, arms extended.",
                "Lower it behind your head until elbows bend to 90 degrees.",
                "Straighten your arms to lift it back overhead.",
            ],
            imageName: "guide-overhead-tricep-extension"
        ),
        "Skull Crusher": ExerciseGuide(
            summary: "A lying EZ-bar extension that isolates the triceps by bending only at the elbows.",
            primaryMuscles: "Triceps",
            secondaryMuscles: "",
            steps: [
                "Lie on a bench with feet flat on the floor.",
                "Hold the EZ bar above your chest, palms facing your feet.",
                "Bend your elbows to lower the bar toward your forehead.",
                "Keep elbows from flaring out as you lower.",
                "Straighten your arms back to the starting position.",
            ],
            imageName: "guide-skull-crusher"
        ),
        "Close-Grip Bench Press": ExerciseGuide(
            summary: "A narrow-grip bench press that emphasizes the triceps while also working the chest and shoulders.",
            primaryMuscles: "Triceps",
            secondaryMuscles: "Front delts, Chest",
            steps: [
                "Lie on the bench with feet flat on the floor.",
                "Grip the bar palms-down, slightly narrower than shoulder-width.",
                "Unrack the bar and lower it slowly to your lower chest.",
                "Keep your elbows tucked close to your body.",
                "Press the bar up until your arms are straight.",
            ],
            imageName: "guide-close-grip-bench-press"
        ),

        // MARK: Core
        "Cable Crunch": ExerciseGuide(
            summary: "A kneeling cable exercise that trains the abs by crunching the torso down against resistance.",
            primaryMuscles: "Abs",
            secondaryMuscles: "Obliques",
            steps: [
                "Kneel facing the cable machine with the rope set high.",
                "Hold one rope end in each hand by your head.",
                "Keep your hands fixed at your head throughout.",
                "Crunch down by bringing your elbows toward your knees.",
                "Hold briefly, then slowly return to the start.",
            ],
            imageName: "guide-cable-crunch"
        ),
        "Hanging Leg Raise": ExerciseGuide(
            summary: "A hanging bar exercise that trains the abs by lifting the knees and hips toward the chest.",
            primaryMuscles: "Abs",
            secondaryMuscles: "Hip flexors",
            steps: [
                "Hang from a high bar with palms facing forward.",
                "Tighten your abs to lift your knees and hips up.",
                "Raise them toward your chest.",
                "Pause for about one second at the top.",
                "Lower back down slowly and with control.",
            ],
            imageName: "guide-hanging-leg-raise"
        ),
        "Russian Twist": ExerciseGuide(
            summary: "A seated core exercise that trains the obliques by rotating the torso side to side.",
            primaryMuscles: "Obliques",
            secondaryMuscles: "Abs",
            steps: [
                "Sit with knees bent and heels on or near the floor.",
                "Lean back slightly to keep your core engaged.",
                "Clasp your hands together in front of your chest.",
                "Rotate your torso to tap the floor on one side.",
                "Twist to the other side and keep alternating.",
            ],
            imageName: nil
        ),
        "Plank": ExerciseGuide(
            summary: "An isometric hold on the forearms and toes that trains the abs to stabilize the body.",
            primaryMuscles: "Abs",
            secondaryMuscles: "Shoulders, Glutes",
            steps: [
                "Lie face down, then prop up on your forearms and toes.",
                "Keep your shoulders and hips level at the same height.",
                "Tighten your abs and hold a straight line.",
                "Hold the position for your desired time.",
            ],
            imageName: "guide-plank"
        ),
        "Decline Sit Up": ExerciseGuide(
            summary: "A sit-up on a decline bench that trains the abs through a larger range of motion.",
            primaryMuscles: "Abs",
            secondaryMuscles: "Hip flexors",
            steps: [
                "Sit on a decline bench and hook your feet under the pads.",
                "Lower your torso back toward the bench.",
                "Tighten your abs to curl your torso up.",
                "Rise until your chest nears your knees.",
                "Lower back down slowly with control.",
            ],
            imageName: nil
        ),
        "Ab Wheel Rollout": ExerciseGuide(
            summary: "A rolling exercise using an ab wheel that trains the abs to resist body extension.",
            primaryMuscles: "Abs",
            secondaryMuscles: "Shoulders, Lower back",
            steps: [
                "Kneel and grip the ab wheel on the floor below your shoulders.",
                "Brace your core and keep your back flat.",
                "Slowly roll the wheel forward, extending your body.",
                "Stop before your hips sag, then roll back.",
                "Pull yourself back to the start using your abs.",
            ],
            imageName: nil
        ),
    ]
}
