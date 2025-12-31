pub fn safe_option() -> Option<i32,> {
    Some(42,)
}

fn main() {
    let val = safe_option();

    // ❌ This will trigger Clippy lint from lib.rs deny
    // val.unwrap();
    val.unwrap();

    // ✅ Correct usage
    if let Some(v,) = val {
        println!("{}", v);
    }

    // ❌ Unsafe block without SAFETY comment triggers nightly lint
    // unsafe { println!("unsafe"); }

    // ✅ Properly documented unsafe
    // SAFETY: pointer is valid and aligned
    #[allow(unused_unsafe)]
    unsafe {
        println!("safe unsafe block");
    }
}
