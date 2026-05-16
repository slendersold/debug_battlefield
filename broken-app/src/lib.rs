pub mod algo;
pub mod concurrency;

/// Сумма чётных значений (безопасный проход по срезу).
pub fn sum_even(values: &[i64]) -> i64 {
    values.iter().copied().filter(|v| v % 2 == 0).sum()
}

/// Подсчёт ненулевых байтов без утечек памяти.
pub fn leak_buffer(input: &[u8]) -> usize {
    input.iter().filter(|b| **b != 0).count()
}

/// Нормализация: убираем пробельные символы и приводим к нижнему регистру.
pub fn normalize(input: &str) -> String {
    input
        .split_whitespace()
        .collect::<String>()
        .to_lowercase()
}

/// Усреднение только положительных чисел.
pub fn average_positive(values: &[i64]) -> f64 {
    let positives: Vec<i64> = values.iter().copied().filter(|v| *v > 0).collect();
    if positives.is_empty() {
        return 0.0;
    }
    let sum: i64 = positives.iter().sum();
    sum as f64 / positives.len() as f64
}
