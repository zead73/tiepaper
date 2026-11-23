//! A tricky Rust file
use std::fmt;

/* outer /* nested */ still a comment */
struct Wrapper<'a> {
    name: &'a str,   // a lifetime, not a char
    raw: &'static str,
}

fn main() {
    let c = 'x';
    let nl = '\n';
    let r = r#"a "quoted" word"#;
    let s = "line one
line two \" still a string";
    println!("{} {}", c, 0x1F + 1_000u32);
    let t = b"bytes";
}
