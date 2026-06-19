//! This crate provides the `down` language support for tree-sitter.

#![allow(unused)]

use tree_sitter_language::LanguageFn;

extern "C" {
    fn tree_sitter_down() -> *const ();
}

/// The `down` language function for tree-sitter.
pub const LANGUAGE: LanguageFn = unsafe { LanguageFn::from_raw(tree_sitter_down) };

/// The node types of the `down` grammar.
pub const NODE_TYPES: &str = include_str!("../../src/node-types.json");

#[cfg(test)]
mod tests {
    use std::ffi::OsStr;
    use std::process::Command;

    fn get_test_grammar(name: &str) -> String {
        let extension = OsStr::new(name)
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("");
        let path = std::path::Path::new("test").join(name);

        if !path.exists() {
            return format!("test file {:?} not found", path);
        }

        let output = Command::new("tree-sitter")
            .arg("parse")
            .arg(&path)
            .output()
            .expect("failed to run tree-sitter");

        String::from_utf8_lossy(&output.stdout).to_string()
    }
}
