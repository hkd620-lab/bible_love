# Bible_Love Data Rules (Fixed)

## Folder Roles
- tools/source/        : Raw sources (Project Gutenberg etc). NOT used by app.
- tools/inbox/         : Work-in-progress outputs. NOT used by app.
- tools/final/         : App-ready final outputs (EN+KO+ARCHAIC). App uses ONLY this.
- tools/final_en_only/ : Optional final outputs (EN only) for dev/verify.

## Absolute Rule
- The app reads ONLY tools/final/.
- inbox/source are never used directly in the app.

## Naming
- Final path: tools/final/{bookcode}/
- File name: {bookcode}_{chapter3}.txt (example: gen_003.txt)

## UI Labels (Beginner-friendly)
- Bottom nav: Home(처음), Read(읽기), Words(단어), Grammar(문법), Quiz(퀴즈)
- Language toggle: EN+KO(영·한) -> EN(영어) -> KO(한글)
- Verse actions: Listen(듣기), Speak(따라말하기)
