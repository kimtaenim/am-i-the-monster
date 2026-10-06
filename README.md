# Am I the Monster?

정글 유적에서 유물을 캐는 고고학자들 사이에 저주받은 사람이 숨어 있어요. 밤마다 괴물로 변하는 그 사람을 찾아내는 로블록스 게임이에요.

## Studio에서 열기 (Rojo)

1. [Rojo 7](https://rojo.space/docs/v7/getting-started/installation/) CLI와 Roblox Studio 플러그인을 설치해요.
2. 이 폴더에서 `rojo serve` 를 실행해요.
3. Studio에서 새 Baseplate를 열고 기본 `Baseplate`·`SpawnLocation`을 지워요. (정글 바닥과 출발 지점은 게임이 직접 만들어요)
4. Rojo 플러그인에서 **Connect** 를 눌러요.
5. ▶ Play 를 누르면 정글이 만들어져요.

## 폴더

| 폴더 | 하는 일 |
| --- | --- |
| `src/ReplicatedStorage` | 서버·화면이 같이 쓰는 것 (`Config.luau` 숫자 모음, 유물 정의, 대사) |
| `src/ServerScriptService` | 게임 규칙 전부 (서버에서만 실행) |
| `src/StarterPlayer/StarterPlayerScripts` | 화면 UI와 소리 |
| `src/StarterGui` | 화면 UI 틀 |

- 숫자를 바꾸고 싶으면 `src/ReplicatedStorage/Config.luau` 만 고치면 돼요.
- NPC 대사는 `src/ReplicatedStorage/Dialogue/Lines.luau` 한 파일에 모여 있어요.
- Studio에서 손으로 꾸민 것은 `Workspace/HandMade` 폴더에 넣어요. Rojo도 게임도 건드리지 않아요.
