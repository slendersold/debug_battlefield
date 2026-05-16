# Отчёт: модуль 5 — debug_battlefield

**Дата:** 2026-05-16  
**Репозиторий:** один каталог `debug_battlefield/` с двумя crate: `broken-app/` (работа) и `reference-app/` (эталон, без изменений логики).

> Отчёт выстроен **в порядке выполнения задания** (шаги 1→7 из `docs/task5.md`), а не «сводной таблицей в конце».

---

## Репозиторий: можно ли держать reference рядом?

**Да.** В ТЗ явно указана структура с двумя подпроектами в одном дереве (`broken-app/` + `reference-app/`). К сдаче нужны:

- репозиторий/форк с **исправленным** `broken-app` (история коммитов);
- **неизменённый** `reference-app` — достаточно **commit hash** или отдельной ветки/тега в **том же** репозитории.

Текущая раскладка соответствует заданию:

```
debug_battlefield/
├── broken-app/      ← исправления, тесты, бенчмарки, artifacts/
├── reference-app/   ← эталон для сверки (не трогали поведение)
└── REPORT.md
```

`reference-app` не обязан быть отдельным remote — важно, чтобы ревьюер мог воспроизвести сверку (`cargo test` в обоих crate).

---

## Шаг 1. Ознакомление

```bash
cd debug_battlefield/broken-app && cargo check
cd ../reference-app && cargo test   # 7 passed — эталон
cd ../broken-app && cargo test      # до правок: 2 failed (см. ниже)
```

**Падавшие тесты (исходник):** `sums_even_numbers`, `averages_only_positive`.  
Лог-заметка: `broken-app/artifacts/cargo_test_initial.txt`.

**reference-app:** 7/7 OK — зафиксировали ожидаемое поведение перед правками.

---

## Шаг 2. Поиск и исправление багов

### 2.1. Отладчик (gdb)

На логических ошибках, видимых в тестах:

| Тест | Что увидели в gdb | Баг |
|------|-------------------|-----|
| `averages_only_positive` | `sum` по всему срезу, делитель `len` | неверная формула |
| `sums_even_numbers` | цикл `0..=len`, доступ за срезом | off-by-one + UB |

Заметки с командами: `broken-app/artifacts/gdb_notes.txt`.

### 2.2. Miri (UB)

```bash
cargo +nightly miri test   # после исправлений
# 11 passed, UB нет
```

Лог: `broken-app/artifacts/miri_test.log`.  
На исходнике Miri падал бы на `sum_even` / `use_after_free`.

### 2.3. Valgrind (утечки / память)

`valgrind cargo test` **не подходит** — инструментируется только `cargo`.  
Используем:

```bash
cd broken-app && ./scripts/valgrind.sh
```

**После исправления `leak_buffer`:** `definitely lost: 0`, `indirectly lost: 0`, Invalid read/write нет.  
Лог: `broken-app/artifacts/valgrind_integration.log`.

### 2.4. Sanitizer’ы (ASan / TSan)

`criterion` вынесен в optional feature `criterion-bench` — `cargo test` больше не тянет criterion.

```bash
./scripts/asan.sh   # → artifacts/asan_test.log
./scripts/tsan.sh   # → artifacts/tsan_test.log (-Zbuild-std)
```

**ASan:** 11/11 passed. **TSan:** 11/11 passed (`race_increment_is_correct` под `-Zsanitizer=thread`).

### 2.5. Исправления (сводка)

| # | Место | Тип | Действие |
|---|-------|-----|----------|
| 1 | `sum_even` | off-by-one, UB | безопасный итератор |
| 2 | `leak_buffer` | утечка | убран `into_raw`, итератор |
| 3 | `normalize` | логика | `split_whitespace` |
| 4 | `average_positive` | логика | только `v > 0` |
| 5 | `use_after_free` | UAF | удалено |
| 6 | `slow_dedup` | алгоритм | `HashSet`, O(n) |
| 7 | `slow_fib` | алгоритм | итерация O(n) |
| 8 | `concurrency` | data race | `AtomicU64` |

---

## Шаг 3. Подтверждение корректности (после правок)

| Проверка | Результат | Артефакт |
|----------|-----------|----------|
| `cargo test` | **11/11** | `artifacts/cargo_test.log` |
| Miri | **11/11**, UB нет | `artifacts/miri_test.log` |
| Valgrind | **11/11**, definite leak 0 | `artifacts/valgrind_integration.log` |
| reference-app tests | **7/7** | — |

### Регрессионные тесты (добавлены)

`race_increment_is_correct`, `regression_sum_even_empty_slice`, `regression_average_positive_empty`, `regression_normalize_tabs_and_newlines`, `regression_leak_buffer_all_zeros`.

---

## Шаг 4. Узкие места (профилирование)

Сценарий: `cargo run --release --bin demo`.

| Участок | Симптом «до» | Инструмент |
|---------|--------------|------------|
| `slow_fib(32)` | ~**16 ms** | baseline / ручной замер |
| `slow_dedup(10k)` | ~**24 ms** | baseline |
| `sum_even(50k)` | ~22 µs, но UB | Miri + gdb |

Заметки: `artifacts/profiling_notes.txt`.  
```bash
sudo sysctl -w kernel.perf_event_paranoid=-1   # один раз
./scripts/profile.sh
```

Краткий лог: `artifacts/perf_summary.txt`, визуализация: `artifacts/flamegraph.svg`.  
На оптимизированном `demo` доминирует runtime/ядро (fib/dedup уже ~µs); узкие места «до» — `profiling_notes.txt` + `baseline_before.txt`.

---

## Шаг 5. Бенчмарки «до» оптимизации

```bash
# исходные slow_fib / slow_dedup (отдельный -O бинарник, см. baseline_before.txt)
cargo bench --bench baseline   # на сломанном fib/dedup — долго; зафиксировано вручную
```

| Функция | До | Артефакт |
|---------|-----|----------|
| `slow_fib(32)` | 15.9 ms | `artifacts/baseline_before.txt` |
| `slow_dedup(10k)` | 24.5 ms | там же |
| `sum_even(50k)` | ~22 µs* | там же |

\*с UB в исходнике.

---

## Шаг 6. Оптимизация

**Алгоритмическая:** `slow_fib` O(2ⁿ)→O(n); `slow_dedup` O(n²)→O(n) через `HashSet`.  
**Микро:** `leak_buffer` без лишнего `Box`; `sum_even` без `unsafe`.

Имена API в `broken-app` сохранены (`slow_*`); по смыслу совпадают с `fast_*` в reference.

---

## Шаг 7. Проверка «после» + сверка с reference

### 7.1. Повторная верификация

Те же прогоны, что в шаге 3: тесты / Miri / Valgrind — **чисто**.

### 7.2. Бенчмарки «после»

```bash
cd broken-app
cargo bench --bench baseline    # → artifacts/baseline_after.txt
cargo bench --bench criterion -- --noplot  # → artifacts/criterion_broken.txt

cd ../reference-app
cargo bench --bench baseline    # → artifacts/baseline_reference.txt
cargo bench --bench criterion -- --noplot  # → artifacts/criterion_reference.txt
```

| Бенч | До | broken-app (после) | reference-app |
|------|-----|-------------------|---------------|
| fib(32) | 15.9 ms | **~38 ns** | ~38 ns |
| dedup(10k) | 24.5 ms | **~264 µs** | ~266 µs |
| sum_even(50k) | ~22 µs | ~25 µs | ~25 µs |

**Ускорение:** fib ≈ **4×10⁵×**, dedup ≈ **90×**. После оптимизации broken ≈ reference (±4% criterion).

### 7.3. Сверка поведения с reference-app

| API | Совпадение |
|-----|------------|
| `sum_even`, `leak_buffer`, `normalize`, `average_positive` | да |
| `slow_fib` / `fast_fib`, `slow_dedup` / `fast_dedup` | да |
| `race_increment` (4×1000 → 4000) | да |

---

## Лист самопроверки (из ТЗ)

| # | Критерий | Статус | Комментарий |
|---|----------|--------|-------------|
| 1 | Собраны артефакты | ✅ | `broken-app/artifacts/`, `reference-app/artifacts/` |
| 2 | Все тесты проходят | ✅ | broken 11/11, reference 7/7 |
| 3 | ≥5 багов устранены | ✅ | 8 типов дефектов |
| 4 | Регрессионные тесты | ✅ | 5 новых |
| 5 | Miri без UB | ✅ | лог `miri_test.log` |
| 6 | Valgrind без утечек/ошибок | ✅ | `definitely lost: 0`; нет Invalid r/w |
| 7 | ASan/TSan на ключевых тестах | ✅ | `asan_test.log`, `tsan_test.log` |
| 8 | Бенчмарки до/после, ускорение | ✅ | baseline_before / after + criterion |
| 9 | Оптимизации документированы | ✅ | шаги 6–7 |
| 10 | Отладчик / Miri / Valgrind в отчёте | ✅ | шаги 2–3, gdb_notes, valgrind.sh |
| 11 | До/после (время) | ✅ | таблица §7.2 |
| 12 | Сверка с reference | ✅ | один репозиторий, два crate |
| 13 | Flamegraph / perf | ✅ | `perf.data`, `perf_report.txt` (`./scripts/profile.sh`) |
| 14 | Код без лишних зависимостей | ✅ | только `criterion` в dev-deps |

---

## Структура артефактов

```
debug_battlefield/
├── REPORT.md
├── broken-app/
│   ├── artifacts/
│   │   ├── cargo_test_initial.txt
│   │   ├── cargo_test.log
│   │   ├── gdb_notes.txt
│   │   ├── miri_test.log
│   │   ├── valgrind_integration.log
│   │   ├── profiling_notes.txt
│   │   ├── perf_summary.txt / flamegraph.svg
│   │   ├── asan_test.log / tsan_test.log
│   │   ├── baseline_before.txt
│   │   ├── baseline_after.txt
│   │   └── criterion_broken.txt
│   └── scripts/
│       ├── valgrind.sh / asan.sh / tsan.sh
│       ├── profile.sh / bench_criterion.sh
│       └── compare.sh
└── reference-app/artifacts/
    ├── baseline_reference.txt
    └── criterion_reference.txt
```

---

## Команды для воспроизведения

```bash
cd debug_battlefield/broken-app
export CARGO_TARGET_DIR=target
cargo test --tests
cargo +nightly miri test
./scripts/valgrind.sh
./scripts/asan.sh
./scripts/tsan.sh
sudo sysctl -w kernel.perf_event_paranoid=-1 && ./scripts/profile.sh
cargo bench --bench baseline
./scripts/bench_criterion.sh -- --noplot

cd ../reference-app
cargo test
cargo bench --bench criterion --features criterion-bench -- --noplot
```
