#[repr(C)]
#[derive(Clone, Copy)]
pub struct Point {
    pub x: f32,
    pub y: f32,
    pub id: i32,
}
#[derive(Default)]
pub struct Pinch {
    ids: [i32; 5],
    start: f64,
    last: f64,
    baseline: f32,
    filtered: f32,
    frames: u32,
    fired: bool,
}
impl Pinch {
    pub fn update(&mut self, points: &[Point], time: f64, threshold: f32) -> i32 {
        if points.len() != 5
            || !time.is_finite()
            || points.iter().any(|p| {
                !p.x.is_finite()
                    || !p.y.is_finite()
                    || !(0.0..=1.0).contains(&p.x)
                    || !(0.0..=1.0).contains(&p.y)
            })
        {
            *self = Self::default();
            return 0;
        }
        let mut ids: [i32; 5] = std::array::from_fn(|i| points[i].id);
        ids.sort_unstable();
        if ids.windows(2).any(|w| w[0] == w[1]) {
            *self = Self::default();
            return 0;
        }
        let x = points.iter().map(|p| p.x).sum::<f32>() / 5.0;
        let y = points.iter().map(|p| p.y).sum::<f32>() / 5.0;
        let radius = (points
            .iter()
            .map(|p| (p.x - x).powi(2) + (p.y - y).powi(2))
            .sum::<f32>()
            / 5.0)
            .sqrt();
        if self.frames == 0 || ids != self.ids || time < self.last || time - self.last > 0.25 {
            *self = Self {
                ids,
                start: time,
                last: time,
                baseline: radius,
                filtered: radius,
                frames: 1,
                fired: false,
            };
            return 0;
        }
        self.last = time;
        self.frames += 1;
        self.filtered = self.filtered * 0.6 + radius * 0.4;
        if self.fired || self.baseline < 0.075 || time - self.start < 0.08 || self.frames < 5 {
            return 0;
        }
        let ratio = self.filtered / self.baseline;
        let movement = self.filtered - self.baseline;
        let result = if ratio < 1.0 - threshold && movement < -0.025 {
            1
        } else if ratio > 1.0 + threshold && movement > 0.025 {
            2
        } else {
            0
        };
        if result != 0 {
            self.fired = true;
        }
        result
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    fn points(scale: f32, dx: f32) -> [Point; 5] {
        std::array::from_fn(|i| {
            let a = i as f32 * std::f32::consts::TAU / 5.0;
            Point {
                x: 0.5 + dx + 0.25 * scale * a.cos(),
                y: 0.5 + 0.25 * scale * a.sin(),
                id: i as i32,
            }
        })
    }
    fn run(scale: f32) -> Vec<i32> {
        let mut p = Pinch::default();
        (0..30)
            .map(|i| {
                p.update(
                    &points(if i < 10 { 1.0 } else { scale }, 0.0),
                    i as f64 * 0.01,
                    0.24,
                )
            })
            .filter(|v| *v != 0)
            .collect()
    }
    #[test]
    fn pinch_in_and_out_fire_once() {
        assert_eq!(run(0.60), vec![1]);
        assert_eq!(run(1.40), vec![2]);
    }
    #[test]
    fn translation_and_jitter_are_ignored() {
        let mut p = Pinch::default();
        for i in 0..30 {
            assert_eq!(
                p.update(
                    &points(1.0 + (i % 2) as f32 * 0.01, i as f32 * 0.003),
                    i as f64 * 0.01,
                    0.24
                ),
                0
            );
        }
    }
    #[test]
    fn wrong_finger_count_and_recontact_reset() {
        let mut p = Pinch::default();
        for i in 0..10 {
            p.update(&points(1.0, 0.0), i as f64 * 0.01, 0.24);
        }
        assert_eq!(p.update(&points(0.5, 0.0)[..4], 0.11, 0.24), 0);
        for i in 0..10 {
            assert_eq!(p.update(&points(0.5, 0.0), 0.12 + i as f64 * 0.01, 0.24), 0);
        }
    }
    #[test]
    fn invalid_data_cannot_trigger() {
        let mut p = Pinch::default();
        let mut pts = points(1.0, 0.0);
        pts[2].x = f32::NAN;
        assert_eq!(p.update(&pts, 1.0, 0.24), 0);
        pts = points(1.0, 0.0);
        pts[2].id = pts[1].id;
        assert_eq!(p.update(&pts, 1.0, 0.24), 0);
    }
}
