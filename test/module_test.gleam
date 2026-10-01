import gleam/list
import gleam/option
import gleeunit
import gleeunit/should
import module

pub fn main() -> Nil {
  gleeunit.main()
}

//-----------------------------------------------------------------------------------------------//
//                                            Literal                                            //
//-----------------------------------------------------------------------------------------------//

pub fn string_literal_node_to_string_test() {
  module.literal.string("Hello, world!")
  |> module.to_string
  |> should.equal("\"Hello, world!\"")
}

pub fn int_literal_node_to_string_test() {
  module.literal.int(129)
  |> module.to_string
  |> should.equal("129")
}

pub fn float_literal_node_to_string_test() {
  module.literal.float(43.7)
  |> module.to_string
  |> should.equal("43.7")
}

pub fn bool_literal_node_to_string_test() {
  module.literal.bool(True)
  |> module.to_string
  |> should.equal("True")

  module.literal.bool(False)
  |> module.to_string
  |> should.equal("False")
}

pub fn tuple_literal_node_to_string_test() {
  module.literal.tuple([
    module.literal.string("A"),
    module.literal.int(12),
    module.literal.bool(False),
  ])
  |> module.to_string
  |> should.equal("#(\"A\", 12, False)")
}

pub fn list_literal_node_to_string_test() {
  module.literal.list([
    module.literal.string("red"),
    module.literal.string("green"),
    module.literal.string("blue"),
  ])
  |> module.to_string
  |> should.equal("[\"red\", \"green\", \"blue\"]")
}

//-----------------------------------------------------------------------------------------------//
//                                          Identifier                                           //
//-----------------------------------------------------------------------------------------------//

pub fn identifier_node_to_string_test() {
  module.identifier.create("my_identifier")
  |> module.to_string
  |> should.equal("my_identifier")
}

//-----------------------------------------------------------------------------------------------//
//                                          Identifier                                           //
//-----------------------------------------------------------------------------------------------//

pub fn binop_node_add_to_string_test() {
  module.binop.create(
    module.identifier.create("a"),
    module.Add,
    module.identifier.create("b"),
  )
  |> module.to_string
  |> should.equal("a + b")
}

pub fn binop_node_subtract_to_string_test() {
  module.binop.create(
    module.identifier.create("a"),
    module.Subtract,
    module.identifier.create("b"),
  )
  |> module.to_string
  |> should.equal("a - b")
}

pub fn binop_node_multiply_to_string_test() {
  module.binop.create(
    module.identifier.create("a"),
    module.Multiply,
    module.identifier.create("b"),
  )
  |> module.to_string
  |> should.equal("a * b")
}

pub fn binop_node_divide_to_string_test() {
  module.binop.create(
    module.identifier.create("a"),
    module.Divide,
    module.identifier.create("b"),
  )
  |> module.to_string
  |> should.equal("a / b")
}

pub fn binop_node_float_add_to_string_test() {
  module.binop.create(
    module.identifier.create("a"),
    module.FloatAdd,
    module.identifier.create("b"),
  )
  |> module.to_string
  |> should.equal("a +. b")
}

pub fn binop_node_float_subtract_to_string_test() {
  module.binop.create(
    module.identifier.create("a"),
    module.FloatSubtract,
    module.identifier.create("b"),
  )
  |> module.to_string
  |> should.equal("a -. b")
}

pub fn binop_node_float_multiply_to_string_test() {
  module.binop.create(
    module.identifier.create("a"),
    module.FloatMultiply,
    module.identifier.create("b"),
  )
  |> module.to_string
  |> should.equal("a *. b")
}

pub fn binop_node_float_divide_to_string_test() {
  module.binop.create(
    module.identifier.create("a"),
    module.FloatDivide,
    module.identifier.create("b"),
  )
  |> module.to_string
  |> should.equal("a /. b")
}

pub fn binop_node_string_concat_to_string_test() {
  module.binop.create(
    module.identifier.create("a"),
    module.StringConcat,
    module.identifier.create("b"),
  )
  |> module.to_string
  |> should.equal("a <> b")
}

pub fn binop_node_pipe_to_string_test() {
  module.binop.create(
    module.identifier.create("a"),
    module.Pipe,
    module.identifier.create("b"),
  )
  |> module.to_string
  |> should.equal("a |> b")
}

pub fn binop_node_access_to_string_test() {
  module.binop.create(
    module.identifier.create("a"),
    module.Access,
    module.identifier.create("b"),
  )
  |> module.to_string
  |> should.equal("a.b")
}

//-----------------------------------------------------------------------------------------------//
//                                         Function Call                                         //
//-----------------------------------------------------------------------------------------------//

pub fn function_call_node_to_string_test() {
  module.function_call.create(module.binop.create(
    module.identifier.create("io"),
    module.Access,
    module.identifier.create("println"),
  ))
  |> module.function_call.add(module.literal.string("Hello, world!"))
  |> module.to_string
  |> should.equal("io.println(\"Hello, world!\")")
}

//-----------------------------------------------------------------------------------------------//
//                                        Type Definition                                        //
//-----------------------------------------------------------------------------------------------//

pub fn type_definition_enum_node_to_string_test() {
  module.type_definition.create("Color")
  |> module.type_definition.add(module.type_variant.create("Red"))
  |> module.type_definition.add(module.type_variant.create("Green"))
  |> module.type_definition.add(module.type_variant.create("Blue"))
  |> module.to_string
  |> should.equal("type Color {\n  Red\n  Green\n  Blue\n}")
}

pub fn type_definition_node_to_string_test() {
  module.type_definition.create("Color")
  |> module.type_definition.add(
    module.type_variant.create("Color")
    |> module.type_variant.field(
      option.Some("red"),
      module.identifier.create("Int"),
    )
    |> module.type_variant.field(
      option.Some("green"),
      module.identifier.create("Int"),
    )
    |> module.type_variant.field(
      option.Some("blue"),
      module.identifier.create("Int"),
    ),
  )
  |> module.to_string
  |> should.equal(
    "type Color {\n  Color(\n    red: Int,\n    green: Int,\n    blue: Int,\n  )\n}",
  )
}

//-----------------------------------------------------------------------------------------------//
//                                      Function Definition                                      //
//-----------------------------------------------------------------------------------------------//

pub fn function_definition_node_to_string_test() {
  module.function_definition.create()
  |> module.function_definition.with_name("my_function")
  |> module.function_definition.add_parameter(
    "argument0",
    module.identifier.create("Int"),
  )
  |> module.function_definition.add_parameter(
    "argument1",
    module.identifier.create("Int"),
  )
  |> module.function_definition.add_parameter(
    "argument2",
    module.identifier.create("Int"),
  )
  |> module.function_definition.add_parameter(
    "argument3",
    module.identifier.create("Int"),
  )
  |> module.function_definition.add_parameter(
    "argument4",
    module.identifier.create("Int"),
  )
  |> module.to_string
  |> should.equal(
    "fn my_function(\n  argument0: Int,\n  argument1: Int,\n  argument2: Int,\n  argument3: Int,\n  argument4: Int,\n) {\n}",
  )
}

//-----------------------------------------------------------------------------------------------//
//                                            Imports                                            //
//-----------------------------------------------------------------------------------------------//

pub fn imports_001_test() {
  let module =
    module.root.create()
    |> module.add_import(["a", "b"])
    |> module.add_import(["c", "d"])
    |> module.merge_imports(
      module.root.create()
      |> module.add_import(["a", "b"])
      |> module.add_import(["e", "f"]),
    )

  module.imports
  |> list.map(fn(import_) { import_.path })
  |> should.equal([
    ["a", "b"],
    ["c", "d"],
    ["e", "f"],
  ])
}

pub fn imports_002_test() {
  let module =
    module.root.create()
    |> module.add_import(["a", "b"])
    |> module.add_import(["c", "d"])
    |> module.merge_imports(
      module.root.create()
      |> module.add_import(["e", "f"])
      |> module.add_import(["a", "b"]),
    )
    |> module.merge_imports(
      module.root.create()
      |> module.add_import(["c", "d"])
      |> module.add_import(["g", "h"]),
    )

  module.imports
  |> list.map(fn(import_) { import_.path })
  |> should.equal([
    ["a", "b"],
    ["c", "d"],
    ["e", "f"],
    ["g", "h"],
  ])
}

pub fn imports_003_test() {
  let module =
    module.root.create()
    |> module.add_aliased_import(["b", "c"], "d")
    |> module.add_import(["a", "b"])
    |> module.add_aliased_import(["b", "c"], "d")

  module.imports
  |> list.map(fn(import_) { #(import_.path, import_.alias) })
  |> should.equal([
    #(["a", "b"], option.None),
    #(["b", "c"], option.Some("d")),
  ])
}
