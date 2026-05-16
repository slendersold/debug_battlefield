use std::collections::HashSet;

/// Дедупликация с сохранением порядка первых вхождений, O(n) по времени.
pub fn slow_dedup(values: &[u64]) -> Vec<u64> {
    let mut seen = HashSet::with_capacity(values.len());
    let mut out = Vec::with_capacity(values.len());
    for &v in values {
        if seen.insert(v) {
            out.push(v);
        }
    }
    out.sort_unstable();
    out
}

/// Итеративное вычисление числа Фибоначчи за O(n).
pub fn slow_fib(n: u64) -> u64 {
    match n {
        0 => 0,
        1 => 1,
        _ => {
            let mut a = 0;
            let mut b = 1;
            for _ in 2..=n {
                let next = a + b;
                a = b;
                b = next;
            }
            b
        }
    }
}
