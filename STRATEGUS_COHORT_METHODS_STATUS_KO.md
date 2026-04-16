# Strategus Cohort Methods 현재 상태 정리


## 1. 기본적인 밑그림

현재 `Strategus Cohort Methods` 셸은 다음 역할을 하는 것으로 설계되어 있다.

1. 사용자가 cohort method study를 설계하는 데 필요한 입력을 수집한다.
2. 그 입력을 파일 기반 artifact로 남긴다.
3. 나중에 ACP 없이도 실행 가능한 순수 R 스크립트를 생성한다.
4. 장기적으로는 ACP가 comparator/analytic settings recommendation을 도와주는 구조로 확장된다.

## 2. 현재 전체 흐름의 큰 구조

현재 구현된 cohort methods shell의 큰 흐름은 아래와 같다.

1. study intent 입력
2. target / comparator / outcome cohort ID 입력
3. 입력한 cohort ID의 유효성 검사
4. comparison label 결정
5. cohort ID remap 여부 결정
6. negative control concept set / covariate concept set placeholder 입력
7. **analytic settings 수집 (핵심)**
8. cohort JSON 복사 및 role / mapping artifact 생성
9. concept set placeholder artifact 생성
10. cohort method용 defaults / state / TODO artifact 생성
11. generated R script 작성

이 중 7번 analytic settings가 이번 세션에서 가장 많이 확장된 부분이다.

## 3. 현재까지 구현된 것

### 3.1 cohort / concept set 입력 흐름

현재 입력 흐름에서는 아래 항목을 다룰 수 있다.

- target cohort ID
- comparator cohort ID
- outcome cohort ID
  - 여러 개를 하나씩 추가하는 방식
- negative control concept set ID
- covariate include concept set ID
- covariate exclude concept set ID

이 concept set 관련 값들은 아직 실제 concept definition을 생성하는 단계까지 가진 않지만,
placeholder artifact와 trace 정보로는 남기고 있다.

### 3.2 analytic settings 기본 구조

먼저 사용자는 analytic settings를 어떻게 구성할지 고른다.

- `1. Step-by-step`
- `2. Free-text`

그리고 각 방식은 아래처럼 동작한다.

#### Step-by-step

현재는 아래 section 흐름만 따라간다.

- study population
- time-at-risk
- propensity score adjustment
- outcome model

다만 이 section 안의 세부 설정 입력은 아직 TODO다.


#### Free-text

free-text는 사용자가 자연어로 analytic settings 관련 설명을 주는 방식이다.

현재는 아래 우선순위로 입력을 받는다.

1. 함수 인자 `analyticSettingsDescription`
2. 함수 인자 `analyticSettingsDescriptionPath`
3. interactive 입력

### 3.3 free-text recommendation artifact

free-text description이 준비되면 현재 shell은 두 종류의 artifact를 만든다.

#### 1) ACP/stub 응답 artifact

- `outputs/cm_acp_specifications_recommendation.json`

이 파일은 원래 앞으로 ACP flow

- `cohort_methods_specifications_recommendation`

의 응답을 저장하는 자리가 될 예정이다.

현재는 ACP가 아직 구현되지 않았기 때문에,

- ACP helper가 없거나
- ACP bridge가 연결되지 않았거나
- flow가 아직 없으면

stub placeholder 응답을 저장한다.

#### 2) 사용자 확인용 recommendation artifact

- `outputs/cm_analytic_settings_recommendation.json`

이 파일은 free-text description을 바탕으로 만든 dummy recommendation이다.
현재는 실제 recommendation engine이 아니라 placeholder 형태다.

### 3.4 ACP placeholder 호출 단계

현재 free-text 흐름에는 incidence shell을 참고한 ACP 호출 단계가 추가되어 있다.

다만 아직 ACP는 구현되어있지 않다.

### 3.5 generated script

현재 shell은 cohort methods용 generated script도 만든다.

- `03_generate_cohorts.R`
- `04_keeper_review.R`
- `05_diagnostics.R`
- `06_cm_spec.R`
- `07_cm_run_analyses.R`


## 4. 아직 남아 있는 TODO

### 4.1 cohort methods specifications recommendation ACP

가장 큰 TODO는 실제 ACP flow 구현이다.

- `/flows/cohort_methods_specifications_recommendation`

가 실제로 만들어져야 한다.

그리고 그 응답 형식도 정해야 한다.

예:

- recommendation payload의 schema
- defaults를 어떻게 override할지
- profile name / section별 설정을 어떻게 표현할지

### 4.2 comparator setting ACP 연결

또 하나 중요한 TODO는 comparator setting 쪽에도 ACP 연결을 넣는 것이다.

- comparator setting도 Strategus incidence shell처럼 ACP가 개입하는 구조로 확장할 필요가 있다.
- 다만 구체적으로:
  - 어느 시점에 호출할지
  - 어떤 flow 이름/contract로 갈지
  - request / response schema를 어떻게 정의할지

는 아직 결정되지 않았다.

### 4.3 step-by-step 세부 프롬프트

현재 step-by-step은 section 흐름만 있고 실제 상세 입력은 TODO다.

앞으로 각 섹션에 대해 세부 prompt를 구현해야 한다.

- study population settings
- time-at-risk settings
- propensity score adjustment settings
- outcome model settings

필요하면 covariate settings도 analytic settings flow에 다시 통합할지 결정해야 한다.

### 4.4 incidence shell과의 구조 정렬

지금 cohort methods ACP 호출 구조는 incidence shell과 완전히 같지 않다.

앞으로 결정해야 할 것:

- cohort methods도 shell 초반에 `acp_connect(acpUrl)`를 명시할지
- incidence shell의 `acp_try()` 패턴을 그대로 가져올지
- failure policy를 incidence처럼 더 강하게 가져갈지, 지금처럼 stub fallback을 유지할지
- checkpoint / resume를 ACP 단계까지 incidence처럼 정교화할지

### 4.5 recommendation 결과의 실제 반영

현재 free-text recommendation은 dummy placeholder다.

앞으로는 ACP 응답을 받아서:

- `effective_analytic_settings`에 실제로 반영하고
- `cm_analysis_defaults.json`에 반영하고
- 필요하면 사용자 확인 후 수정할 수 있게 해야 한다.

### 4.6 테스트 / 회귀 검증

현재는 parse + dry-run + artifact 확인 수준의 검증이 중심이다.

앞으로는 최소한 아래가 더 필요하다.

- step-by-step 경로 회귀 검증
- free-text text-arg 경로
- free-text path-arg 경로
- ACP stub fallback 경로
- cache/resume 경로
