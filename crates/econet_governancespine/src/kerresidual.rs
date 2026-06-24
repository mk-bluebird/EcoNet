// File: crates/econet_governancespine/src/kerresidual.rs
pub fn compute_Vt(r: &[f32], w: &[f32]) -> f32 {
    assert_eq!(r.len(), w.len());
    let mut vt: f32 = 0.0;
    for (rj, wj) in r.iter().zip(w.iter()) {
        if *wj > 0.0 {
            vt += wj * rj * rj;
        }
    }
    vt
}
