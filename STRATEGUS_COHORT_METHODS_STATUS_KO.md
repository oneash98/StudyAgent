# Strategus Cohort Methods 현재 상태 정리


## 1. 현재 이 셸이 맡는 역할

현재 `Strategus Cohort Methods` 셸은 아래 목적을 가진다.

1. cohort method study 설계에 필요한 입력을 수집한다.
2. 입력과 중간 판단 과정을 artifact로 남긴다.
3. 나중에 ACP 없이도 실행 가능한 순수 R 스크립트를 생성한다.
4. 개발 기간에는 `study intent split`을 우회하고, fixed statements 기반으로 phenotype recommendation과 cohort selection을 진행한다.
5. 가능한 경우 cohort methods 자체 캐시 또는 cohort incidence에서 이미 확정한 cohort selection을 재사용한다.


## 2. 현재 전체 흐름의 큰 구조

현재 구현된 cohort methods shell의 큰 흐름은 아래와 같다.

1. study intent 입력 또는 복원
2. fixed statements 확보
   - target statement
   - comparator statement
   - outcome statement
3. role별 phenotype recommendation / cache reuse 흐름 수행
   - target
   - comparator
   - outcome
4. 최종 target / comparator / outcome cohort ID 확정
5. cohort ID 유효성 검사
6. comparison label 결정
7. cohort ID remap 여부 결정
8. negative control concept set / covariate concept set placeholder 입력
9. analytic settings 수집
10. cohort JSON 복사 및 role / mapping artifact 생성
11. defaults / state / TODO artifact 생성
12. generated R script 작성

즉, 예전처럼 시작하자마자 target/comparator/outcome ID를 먼저 받는 구조가 아니라,
먼저 statement를 확보한 뒤 recommendation 또는 cache reuse를 통해 cohort를 정하는 흐름으로 바뀌었다.


## 3. 현재까지 구현된 것

### 3.1 fixed statements 기반 입력 구조

현재 cohort methods shell은 `study intent split`을 아직 구현하지 않았다.

대신 아래 세 statement를 직접 사용한다.

- `targetStatement`
- `comparatorStatement`
- `outcomeStatement`

statement 값의 우선순위는 현재 아래 방향으로 구현되어 있다.

1. 함수 인자
2. cached `manual_intent.json` 또는 `manual_inputs.json`
3. interactive prompt default
4. 최후 fallback 문구

현재 개발용 기본 문구는 아래와 같다.

- target: `Patients with a metformin prescription.`
- comparator: `Patients with a sulfonylurea prescription.`
- outcome: `Gastrointestinal bleeding.`


### 3.2 role별 phenotype recommendation 흐름

각 statement마다 incidence shell과 유사한 recommendation 흐름을 돈다.

- target statement -> phenotype recommendation
- comparator statement -> phenotype recommendation
- outcome statement -> phenotype recommendation

artifact도 role별로 분리되어 있다.

- `outputs/recommendations_target.json`
- `outputs/recommendations_comparator.json`
- `outputs/recommendations_outcome.json`

window 2 재조회 시에는 같은 디렉터리에 `*_window2.json`이 생성된다.

selection 규칙은 현재 아래와 같다.

- target: 단일 선택
- comparator: 단일 선택
- outcome: 다중 선택


### 3.3 cache reuse 흐름

현재 recommendation 전에 cache reuse 여부를 먼저 판단한다.

우선순위는 아래와 같다.

1. cohort methods 자체의 selected cohort cache가 있으면 그것을 쓸지 먼저 묻는다.
2. cohort methods cache가 없고 cohort incidence selected cohort cache가 있으면 incidence cache를 쓸지 묻는다.
3. 둘 다 없으면 phenotype recommendation을 진행한다.

현재 incidence에서 재사용하는 것은 recommendation artifact 자체가 아니라,
이미 최종 확정되어 저장된 cohort selection이다.

즉, 아래 경로를 참고한다.

- `demo-strategus-cohort-incidence/outputs/cohort_id_map.json`
- `demo-strategus-cohort-incidence/selected-target-cohorts`
- `demo-strategus-cohort-incidence/selected-outcome-cohorts`

comparator는 incidence 쪽에서 바로 가져올 selection이 없으므로,
현재는 cohort methods cache 또는 새 recommendation만 사용한다.


### 3.4 cache prompt 문구와 표시 정보

현재 cache reuse prompt는 가능하면 incidence shell wording과 비슷하게 맞추는 방향으로 작성되어 있다.

또한 incidence cache reuse를 물을 때는 단순히 경로만 묻지 않고,
어떤 cohort를 재사용하는지도 함께 보여준다.

예를 들면 아래와 같은 형태를 목표로 한다.

- `Use cached incidence target cohort selection [Metformin exposure (ID ...)] at ...?`
- `Use cached incidence outcome cohort selection [Gastrointestinal bleeding (ID ...), ...] at ...?`

즉, cache를 쓸지 결정하기 전에 cohort name + ID를 같이 확인할 수 있다.


### 3.5 explicit cohort ID 우선 처리

non-interactive 실행에서 호출자가 직접 준 cohort ID가 recommendation auto-selection에 의해 덮어써지던 문제가 있었다.

이 부분은 현재 수정되었다.

- `targetCohortId`
- `comparatorCohortId`
- `outcomeCohortIds`

가 함수 인자로 들어오면,
recommendation보다 먼저 그 값을 최종 선택으로 확정한다.

이 결정은 scripted execution의 재현 가능성을 지키기 위해 중요하다.


### 3.6 incidence cache 로딩 보강

처음에는 incidence cache가 존재해도 cohort methods shell이 이를 제대로 감지하지 못하는 문제가 있었다.

주요 원인은 `cohort_id_map.json` 구조 차이였다.

- 실제 incidence artifact는 row-array 형태 JSON을 사용한다.
- 기존 loader는 사실상 column-style 구조만 기대하고 있었다.

현재는 `load_cached_role_selection()`이 두 형태를 모두 읽을 수 있게 보강되었다.


### 3.7 artifact 기록 범위 확장

현재 아래 artifact들에는 fixed statements 및 recommendation/cache 관련 정보가 더 많이 남는다.

- `outputs/manual_intent.json`
- `outputs/manual_inputs.json`
- `outputs/study_agent_state.json`
- `outputs/acp_mcp_todo.json`

특히 `manual_intent.json`에는 더 이상 TODO placeholder 문구 대신 실제 target/comparator/outcome statement가 저장된다.


### 3.8 analytic settings 및 generated script

analytic settings 쪽 기본 구조와 generated script 작성 기능도 계속 유지되고 있다.

generated script는 현재 아래 파일들을 만든다.

- `03_generate_cohorts.R`
- `04_keeper_review.R`
- `05_diagnostics.R`
- `06_cm_spec.R`
- `07_cm_run_analyses.R`

analytic settings는 여전히 다음 두 방식을 지원한다.

- `Step-by-step`
- `Free-text`

다만 이 영역은 이번 세션의 핵심 변경점은 아니고,
현재 핵심 변화는 fixed statements + recommendation/cache 흐름 쪽이다.


## 4. 아직 남아 있는 TODO

### 4.1 phenotype intent split의 실제 구현

현재 cohort methods는 `phenotype_intent_split`을 실제로 돌리지 않는다.

즉,

- target / comparator / outcome 분해를 ACP가 자동으로 해주는 구조는 아직 없다.

지금은 개발 편의를 위해 fixed statements를 쓰고 있으며,
state artifact에서도 이 단계는 `deferred` 성격으로 남기고 있다.


### 4.2 cached manual input 우선순위 정리

explicit function argument override 문제는 수정되었지만,
cached `manual_inputs.json`에 들어 있던 cohort ID가 recommendation/cache보다 먼저 확정되어야 하는지는 아직 정리가 덜 되었다.

현재 남아 있는 리스크는 아래와 같다.

- explicit function argument는 보호된다.
- 하지만 cached manual input 기반 rerun에서는 cohort methods cache 또는 recommendation 쪽으로 selection이 바뀔 수 있다.

즉, `resume`과 cached manual input 사용 정책을 한 번 더 정리할 필요가 있다.


### 4.3 malformed explicit cohort ID 처리

예를 들어 아래처럼 잘못된 값을 함수 인자로 주었을 때

- `targetCohortId = "abc"`

지금은 이것을 즉시 invalid input으로 막지 않고,
자동 선택 경로로 흘려보낼 가능성이 있다.

이 부분은 더 엄격한 validation이 필요하다.


### 4.4 incidence cache 경로 해석 안정화

현재 기본 incidence 경로는 `demo-strategus-cohort-incidence` 이다.

하지만 실제 실행 위치와 `studyAgentBaseDir`에 따라 상대경로 해석이 흔들릴 수 있다.

즉, 아래를 더 안정화할 필요가 있다.

- repo root 기준 fallback
- `studyAgentBaseDir` 기준 해석
- `getwd()`가 달라져도 incidence outputs를 찾을 수 있는지


### 4.5 negative control / covariates concept set 실제 구현 방향

현재 cohort methods shell에서 negative control concept set과 covariate concept set은
수동 concept set ID 입력 + dummy placeholder artifact 생성 수준에 머물러 있다.

실제 구현 단계에서는 concept set definition을 외부 소스에서 가져와 materialize할 수 있어야 한다.

특히 [`OHDSI/OmopConcepts`](https://github.com/OHDSI/OmopConcepts) 저장소에서
negative control 및 covariates 관련 concept set을 가져오는 방향을 검토할 필요가 있다.

즉, 이후 구현에서는 아래 요구사항을 만족하도록 설계하는 것이 좋다.

- negative control concept set 선택 시 해당 repo에서 실제 concept set definition을 가져올 수 있어야 한다.
- covariate include / exclude concept set도 동일하게 repo 기반으로 실제 definition을 가져올 수 있어야 한다.
- 현재의 dummy placeholder JSON은 임시 단계로만 유지하고, 장기적으로는 imported concept set artifact로 대체해야 한다.
- artifact / generated script / TODO 출력에도 "concept set ID만 저장된 상태"가 아니라 "어느 repo source에서 어떤 concept set을 가져왔는지"가 남도록 하는 것이 바람직하다.


### 4.5 step-by-step analytic settings 세부 프롬프트

현재 step-by-step은 section 흐름만 있고 실제 상세 입력은 TODO다.

앞으로 각 섹션에 대해 세부 prompt를 구현해야 한다.

- study population settings
- time-at-risk settings
- propensity score adjustment settings
- outcome model settings

필요하면 covariate settings를 analytic settings flow에 다시 통합할지도 결정해야 한다.


### 4.6 cohort methods specifications recommendation ACP

analytic settings 영역의 큰 TODO는 여전히 실제 ACP flow 구현이다.

- `/flows/cohort_methods_specifications_recommendation`

가 실제로 만들어져야 한다.

그리고 그 응답 형식도 정해야 한다.

- recommendation payload schema
- defaults override 방식
- section별 설정 표현 방식


### 4.7 incidence shell과의 구조 정렬

지금 cohort methods의 recommendation/cache 흐름은 incidence shell을 참고했지만,
구조적으로 완전히 같은 것은 아니다.

앞으로 결정해야 할 것:

- cohort methods도 shell 초반에 `acp_connect(acpUrl)`를 명시할지
- incidence shell의 `acp_try()` 패턴을 그대로 가져올지
- failure policy를 incidence처럼 더 강하게 가져갈지, 지금처럼 stub fallback을 유지할지
- checkpoint / resume를 ACP 단계까지 incidence처럼 정교화할지


### 4.8 recommendation / cache 경로 테스트 보강

현재는 코드 검토와 artifact 확인 중심으로 작업이 진행되었고,
테스트는 아직 충분하지 않다.

앞으로 최소한 아래를 더 검증해야 한다.

- explicit function argument가 recommendation에 덮어써지지 않는지
- incidence cache reuse prompt가 실제로 뜨는지
- outcome multi-select가 유지되는지
- cached manual input precedence가 기대대로 동작하는지
- malformed explicit ID가 적절히 실패하는지

또한 기존에 추가된 테스트는 ACP/recommendation/cache 경로를 실질적으로 타지 못한다는 리뷰 지적이 있었으므로,
그 부분도 다시 보강해야 한다.
