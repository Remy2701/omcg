import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string
import omcg/section_comment

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                           Imports                                             //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Represents a gleam import statement.
pub type Import {
  Import(path: List(String), items: List(ImportItem), alias: Option(String))
}

/// Represents an item within a gleam import statement.
pub type ImportItem {
  ImportType(name: String, alias: Option(String))
  ImportItem(name: String, alias: Option(String))
}

/// Adds a new import statement to the module.
/// 
/// ```gleam
/// add_import(module, ["some", "module"])
/// // –––––––––––– Becomes –––––––––––– //
/// import some/module
/// ```
pub fn add_import(module module: Module, path path: List(String)) -> Module {
  Module(..module, imports: [
    Import(path: path, items: [], alias: None),
    ..module.imports
  ])
  |> simplify_imports()
}

/// Adds a new type import to the module.
/// 
/// ```gleam
/// add_type_import(module, ["gleam", "option"], "Option")
/// // –––––––––––– Becomes –––––––––––– //
/// import gleam/option.{type Option}
/// ```
pub fn add_type_import(
  module module: Module,
  path path: List(String),
  name name: String,
) -> Module {
  Module(..module, imports: [
    Import(path: path, items: [ImportType(name, None)], alias: None),
    ..module.imports
  ])
  |> simplify_imports()
}

/// Adds a new aliased type import to the module.
/// 
/// ```gleam
/// add_aliased_type_import(
///   module:, 
///   path: ["gleam", "option"], 
///   name: "Option", 
///   alias: "Opt"
/// )
/// // –––––––––––– Becomes –––––––––––– //
/// import gleam/option.{type Option as Opt}
/// ```
pub fn add_aliased_type_import(
  module module: Module,
  path path: List(String),
  name name: String,
  alias alias: String,
) -> Module {
  Module(..module, imports: [
    Import(path: path, items: [ImportType(name, Some(alias))], alias: None),
    ..module.imports
  ])
  |> simplify_imports()
}

/// Adds a new item import to the module.
/// 
/// ```gleam
/// add_item_import(module, ["gleam", "option"], "Some")
/// // –––––––––––– Becomes –––––––––––– //
/// import gleam/option.{Some}
/// ```
pub fn add_item_import(
  module module: Module,
  path path: List(String),
  name name: String,
) -> Module {
  Module(..module, imports: [
    Import(path: path, items: [ImportItem(name, None)], alias: None),
    ..module.imports
  ])
  |> simplify_imports()
}

/// Adds a new aliased item import to the module.
/// 
/// ```gleam
/// add_aliased_item_import(
///   module:, 
///   path: ["gleam", "option"], 
///   name: "Some", 
///   alias: "S"
/// )
/// // –––––––––––– Becomes –––––––––––– //
/// import gleam/option.{Some as S}
/// ```
pub fn add_aliased_item_import(
  module module: Module,
  path path: List(String),
  name name: String,
  alias alias: String,
) -> Module {
  Module(..module, imports: [
    Import(path: path, items: [ImportItem(name, Some(alias))], alias: None),
    ..module.imports
  ])
  |> simplify_imports()
}

/// Adds a new aliased import to the module.
/// 
/// ```gleam
/// add_aliased_import(
///   module:, 
///   path: ["gleam", "option"], 
///   alias: "opt"
/// )
/// // –––––––––––– Becomes –––––––––––– //
/// import gleam/option as opt
/// ```
pub fn add_aliased_import(
  module module: Module,
  path path: List(String),
  alias alias: String,
) -> Module {
  Module(..module, imports: [
    Import(path: path, items: [], alias: Some(alias)),
    ..module.imports
  ])
  |> simplify_imports()
}

/// Merges the imports of two modules, returning a new module with combined imports
@internal
pub fn merge_imports(a: Module, b: Module) -> Module {
  Module(..a, imports: list.append(a.imports, b.imports))
  |> simplify_imports()
}

/// Simplifies a list of imports by merging matching imports and sorting their items.
fn simplify_import_list(imports: List(Import)) -> List(Import) {
  use imports, current <- list.fold(imports, [])

  let #(matching, rest) =
    list.fold(imports, #([], []), fn(acc, import_: Import) {
      let #(matching, rest) = acc

      let is_matching =
        string.join(import_.path, "/") == string.join(current.path, "/")
        && import_.alias == current.alias

      case is_matching {
        True -> #([import_, ..matching], rest)
        False -> #(matching, [import_, ..rest])
      }
    })
  let #(matching, rest) = #(list.reverse(matching), list.reverse(rest))

  case matching {
    [matching] -> [
      Import(
        path: matching.path,
        items: list.append(matching.items, current.items)
          // TODO: Consider handling alias conflicts here.
          |> list.sort(fn(a, b) {
            case a, b {
              ImportType(..), ImportItem(..) -> order.Lt
              ImportItem(..), ImportType(..) -> order.Gt
              _, _ -> string.compare(a.name, b.name)
            }
          }),
        alias: matching.alias,
      ),
      ..rest
    ]
    _ -> [current, ..rest]
  }
}

/// Simplifies the imports of a module by merging matching imports and sorting them.
fn simplify_imports(module: Module) -> Module {
  Module(
    ..module,
    imports: simplify_import_list(module.imports)
      |> list.sort(fn(a: Import, b: Import) {
        string.compare(string.join(a.path, "/"), string.join(b.path, "/"))
      }),
  )
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                            Module                                             //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// A module represents a node with associated (scoped) imports.
pub type Module {
  Module(node: Node, imports: List(Import))
}

/// Create a new module with the given node and an empty list of imports.
fn create_module(node: Node) -> Module {
  Module(node:, imports: [])
}

/// Modify the node of a module using another module and a modification function.
fn modify_module(
  module: Module,
  other: Module,
  modify: fn(Node, Node) -> Node,
) -> Module {
  Module(..module, node: modify(module.node, other.node))
  |> merge_imports(other)
}

/// Modify the node of a module using a modification function that only takes the module's node.
fn modify_module_self(module: Module, modify: fn(Node) -> Node) -> Module {
  Module(..module, node: modify(module.node))
}

/// Converts a module's node to a string. Does not include imports.
pub fn module_node_to_string(module: Module) -> String {
  module.node
  |> node_to_string(0)
}

/// Converts a module's imports to a string. Does not include the module's node.
pub fn module_imports_to_string(module: Module) -> String {
  string.join(list.map(module.imports, import_to_string), "\n")
}

/// Converts an import to a string.
fn import_to_string(import_: Import) -> String {
  "import "
  <> string.join(import_.path, "/")
  <> case import_.items {
    [] -> ""
    _ -> {
      ".{"
      <> string.join(
        list.map(import_.items, fn(item) {
          item.name
          <> case item.alias {
            Some(alias) -> " as " <> alias
            None -> ""
          }
        }),
        ", ",
      )
      <> "}"
    }
  }
  <> case import_.alias {
    Some(alias) -> " as " <> alias
    None -> ""
  }
}

/// Converts a module to a string, including both its imports and its node.
pub fn to_string(module: Module) -> String {
  let imports_str = module_imports_to_string(module)
  case imports_str {
    "" -> module_node_to_string(module)
    _ -> imports_str <> "\n\n" <> module_node_to_string(module)
  }
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                             Node                                              //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// The parameters of a function definition.
pub type FunctionDefinitionParameter {
  FunctionDefinitionParameter(
    alias: Option(String),
    name: String,
    type_: Option(Node),
  )
}

/// The different operators that can be used in binary operations.
pub type Operator {
  /// Access a field or property using the dot operator `.`
  Access
  /// Addition operator `+`
  Add
  /// Subtraction operator `-`
  Subtract
  /// Multiplication operator `*`
  Multiply
  /// Division operator `/`
  Divide
  /// Floating-point addition operator `+.`
  FloatAdd
  /// Floating-point subtraction operator `-.`
  FloatSubtract
  /// Floating-point division operator `/.`
  FloatDivide
  /// Floating-point multiplication operator `*.`
  FloatMultiply
  /// String concatenation operator `<>`
  StringConcat
  /// Pipe operator `|>`
  Pipe
}

/// The parameters of a function call.
pub type FunctionCallParameter {
  FunctionCallParameter(alias: Option(String), value: Node)
}

/// The field of a type variant.
pub type Field {
  Field(name: Option(String), type_: Node)
}

/// The data content of a type variant.
pub type TypeVariantData {
  TypeVariantData(name: String, fields: List(Field))
}

/// The data content of a case branch.
pub type CaseBranchData {
  CaseBranchData(expression: Node, guard: Option(Node), body: List(Node))
}

/// The different types of literals.
pub type Literal {
  /// A string literal `"Hello, world!"`.
  String(value: String)
  /// An integer literal `42`.
  Int(value: Int)
  /// A floating-point literal `3.14`.
  Float(value: Float)
  /// A boolean literal `True` or `False`.
  Bool(value: Bool)
  /// A tuple literal `#("a", 1, False)`.
  Tuple(value: List(Node))
  /// A list literal `[1, 2, 3]`.
  List(value: List(Node))
}

/// The different types of nodes in the abstract syntax tree.
pub type Node {
  /// A root node containing the entire body of the program.
  Root(body: List(Node))
  /// A function definition node
  FunctionDefinition(
    public: Bool,
    name: Option(String),
    parameters: List(FunctionDefinitionParameter),
    return_type: Option(Node),
    body: List(Node),
  )
  /// A binary operation
  BinaryOperation(lhs: Node, operator: Operator, rhs: Node)
  /// An identifier node representing a variable, function, type or module.
  Identifier(name: String)
  /// A function call node.
  FunctionCall(lhs: Node, parameters: List(FunctionCallParameter))
  /// The variant of a type definition.
  TypeVariant(data: TypeVariantData)
  /// A type definition node
  TypeDefinition(
    public: Bool,
    name: String,
    generics: List(String),
    variants: List(TypeVariantData),
  )
  /// Definition of a constant.
  ConstDefinition(public: Bool, as_type: Bool, name: String, value: Node)
  /// The branch of a case expression.
  CaseBranch(data: CaseBranchData)
  /// A case expression node.
  CaseExpression(expression: Node, branches: List(CaseBranchData))
  /// A use expression node.
  UseExpression(parameters: List(String), rhs: Node)
  /// A literal node.
  Literal(literal: Literal)
  /// A section comment node. (Non-idiomatic gleam)
  SectionComment(comment: String)
  /// The definition of a let-variable.
  LetDefinition(pattern: Node, type_: Option(Node), value: Node)
}

/// Converts a node to its string representation with the given indentation.
pub fn node_to_string(node: Node, indent: Int) -> String {
  let indent_str = fn(indent) { string.repeat("  ", indent) }

  case node {
    Root(body:) ->
      body
      |> list.reverse()
      |> list.map(node_to_string(_, 0))
      |> string.join("\n\n")
    FunctionDefinition(public:, name:, parameters:, return_type:, body:) ->
      case public {
        True -> "pub "
        False -> ""
      }
      <> "fn"
      <> case name {
        Some(name) -> " " <> name
        None -> ""
      }
      <> {
        let parameters_str =
          parameters
          |> list.reverse
          |> list.map(fn(param) {
            case param.alias {
              Some(alias) -> alias <> " "
              _ -> ""
            }
            <> param.name
            <> case param.type_ {
              Some(type_) -> ": " <> node_to_string(type_, indent + 1)
              None -> ""
            }
          })

        let new_line =
          parameters_str
          |> list.any(fn(str) { string.contains(str, "\n") })
        let length =
          parameters_str
          |> list.map(string.length)
          |> int.sum()

        case length > 60 || new_line {
          True ->
            "("
            <> string.join(
              list.map(parameters_str, fn(param) {
                "\n" <> indent_str(indent + 1) <> param <> ","
              }),
              "",
            )
            <> "\n"
            <> indent_str(indent)
            <> ")"
          False -> "(" <> string.join(parameters_str, ", ") <> ")"
        }
      }
      <> case return_type {
        Some(return_type) -> " -> " <> node_to_string(return_type, indent + 1)
        None -> ""
      }
      <> " {"
      <> string.join(
        body
          |> list.reverse()
          |> list.map(fn(expr) {
            "\n" <> indent_str(indent + 1) <> node_to_string(expr, indent + 1)
          }),
        "",
      )
      <> "\n"
      <> indent_str(indent)
      <> "}"
    BinaryOperation(lhs:, operator:, rhs:) -> {
      let lhs_str = node_to_string(lhs, indent)

      lhs_str
      <> case operator {
        Access -> "." <> node_to_string(rhs, indent)
        Add -> " + " <> node_to_string(rhs, indent)
        Subtract -> " - " <> node_to_string(rhs, indent)
        Multiply -> " * " <> node_to_string(rhs, indent)
        Divide -> " / " <> node_to_string(rhs, indent)
        FloatAdd -> " +. " <> node_to_string(rhs, indent)
        FloatSubtract -> " -. " <> node_to_string(rhs, indent)
        FloatDivide -> " /. " <> node_to_string(rhs, indent)
        FloatMultiply -> " *. " <> node_to_string(rhs, indent)
        StringConcat -> {
          let rhs_str = node_to_string(rhs, indent)
          case string.length(lhs_str) + string.length(rhs_str) > 60 {
            True -> "\n" <> indent_str(indent)
            False -> " "
          }
          <> "<> "
          <> node_to_string(rhs, indent)
        }
        Pipe -> {
          let rhs_str = node_to_string(rhs, indent)
          case string.length(lhs_str) + string.length(rhs_str) > 60 {
            True -> "\n" <> indent_str(indent)
            False -> " "
          }
          <> "|> "
          <> node_to_string(rhs, indent)
        }
      }
    }
    Identifier(name:) -> name
    FunctionCall(lhs:, parameters:) ->
      node_to_string(lhs, indent)
      <> case parameters {
        [] -> "()"
        _ -> {
          let parameters_str =
            parameters
            |> list.reverse
            |> list.map(fn(param) {
              case param.alias {
                Some(alias) -> alias <> ": "
                None -> ""
              }
              <> node_to_string(param.value, indent + 1)
            })

          let new_line =
            parameters_str
            |> list.any(fn(str) { string.contains(str, "\n") })
          let length =
            parameters_str
            |> list.map(string.length)
            |> int.sum()

          case length > 60 || new_line {
            True ->
              "("
              <> string.join(
                list.map(parameters_str, fn(param) {
                  "\n" <> indent_str(indent + 1) <> param <> ","
                }),
                "",
              )
              <> "\n"
              <> indent_str(indent)
              <> ")"
            False -> "(" <> string.join(parameters_str, ", ") <> ")"
          }
        }
      }
    TypeVariant(data: variant) ->
      variant.name
      <> case variant.fields {
        [] -> ""
        _ ->
          "(\n"
          <> string.join(
            variant.fields
              |> list.reverse
              |> list.map(fn(field) {
                indent_str(indent + 1)
                <> case field.name {
                  Some(name) -> name <> ": "
                  None -> ""
                }
                <> node_to_string(field.type_, indent + 2)
                <> ",\n"
              }),
            "",
          )
          <> indent_str(indent)
          <> ")"
      }
    TypeDefinition(public:, name:, generics:, variants:) ->
      case public {
        True -> "pub "
        False -> ""
      }
      <> "type "
      <> name
      <> case generics {
        [] -> ""
        _ -> "(" <> string.join(generics, ", ") <> ")"
      }
      <> " {"
      <> string.join(
        variants
          |> list.reverse
          |> list.map(fn(variant) {
            "\n"
            <> indent_str(indent + 1)
            <> node_to_string(TypeVariant(data: variant), indent + 1)
          }),
        "",
      )
      <> "\n"
      <> indent_str(indent)
      <> "}"
    ConstDefinition(public:, as_type:, name:, value:) ->
      case public {
        True -> "pub "
        False -> ""
      }
      <> case as_type {
        True -> "type "
        False -> "const "
      }
      <> name
      <> " = "
      <> node_to_string(value, indent)
    CaseBranch(branch) ->
      node_to_string(branch.expression, indent)
      <> case branch.guard {
        Some(value) -> " if " <> node_to_string(value, indent)
        None -> ""
      }
      <> " -> "
      <> case branch.body {
        [] -> "{}"
        [single] -> node_to_string(single, indent)
        rest ->
          "{\n"
          <> string.join(
            list.map(rest, fn(node) {
              indent_str(indent + 1) <> node_to_string(node, indent + 1)
            }),
            "\n",
          )
          <> "\n"
          <> indent_str(indent)
          <> "}"
      }
    CaseExpression(expression:, branches:) ->
      "case "
      <> node_to_string(expression, indent)
      <> " {"
      <> string.join(
        branches
          |> list.reverse
          |> list.map(fn(branch) {
            "\n"
            <> indent_str(indent + 1)
            <> node_to_string(CaseBranch(branch), indent + 1)
          }),
        "",
      )
      <> "\n"
      <> indent_str(indent)
      <> "}"
    UseExpression(parameters:, rhs:) ->
      "use "
      <> string.join(list.reverse(parameters), ", ")
      <> case parameters {
        [] -> ""
        [_, ..] -> " "
      }
      <> "<- "
      <> node_to_string(rhs, indent)
    Literal(literal:) ->
      case literal {
        String(value:) -> "\"" <> value <> "\""
        Int(value:) -> int.to_string(value)
        Float(value:) -> float.to_string(value)
        Bool(value:) -> bool.to_string(value)
        Tuple(value:) -> {
          let values_str =
            value
            |> list.map(node_to_string(_, indent + 1))

          let new_line =
            values_str
            |> list.any(fn(str) { string.contains(str, "\n") })
          let length =
            values_str
            |> list.map(string.length)
            |> int.sum()

          case length > 60 || new_line {
            True ->
              "#("
              <> string.join(
                list.map(values_str, fn(param) {
                  "\n" <> indent_str(indent + 1) <> param <> ","
                }),
                "",
              )
              <> "\n"
              <> indent_str(indent)
              <> ")"
            False -> "#(" <> string.join(values_str, ", ") <> ")"
          }
        }
        List(value:) -> {
          let values_str =
            value
            |> list.reverse
            |> list.map(node_to_string(_, indent + 1))

          let new_line =
            values_str
            |> list.any(fn(str) { string.contains(str, "\n") })
          let length =
            values_str
            |> list.map(string.length)
            |> int.sum()

          case length > 60 || new_line {
            True ->
              "["
              <> string.join(
                list.map(values_str, fn(param) {
                  "\n" <> indent_str(indent + 1) <> param <> ","
                }),
                "",
              )
              <> "\n"
              <> indent_str(indent)
              <> "]"
            False -> "[" <> string.join(values_str, ", ") <> "]"
          }
        }
      }
    SectionComment(comment) -> section_comment.render(comment)
    LetDefinition(pattern:, type_:, value:) -> {
      "let "
      <> node_to_string(pattern, indent)
      <> case type_ {
        Some(type_node) -> " : " <> node_to_string(type_node, indent)
        None -> ""
      }
      <> " = "
      <> node_to_string(value, indent)
    }
  }
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                             Root                                              //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// The namespace for the root sub-module.
pub const root = RootNS(create: root_node_create, add: root_node_add)

/// The type representing the root sub-module namespace.
pub type RootNS {
  RootNS(create: fn() -> Module, add: fn(Module, Module) -> Module)
}

/// Creates a new root node.
fn root_node_create() -> Module {
  create_module(Root(body: []))
}

/// Adds a node to the root module.
fn root_node_add(module: Module, node: Module) -> Module {
  use module, node <- modify_module(module, node)

  case module, node {
    Root(body:), Root(other_body) -> Root(body: list.append(other_body, body))
    Root(body:), _ -> Root(body: [node, ..body])
    other, _ -> other
  }
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                      Function Definition                                      //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// The namespace for the function definition sub-module.
pub const function_definition = FunctionDefinitionNS(
  create: function_definition_node_create,
  public: function_definition_node_public,
  with_name: function_definition_node_with_name,
  add_parameter: function_definition_node_add_parameter,
  add_untyped_parameter: function_definition_node_add_untyped_parameter,
  add_aliased_parameter: function_definition_node_add_aliased_parameter,
  with_return_type: function_definition_node_with_return_type,
  add: function_definition_node_add,
)

/// The type representing the function definition sub-module namespace.
pub type FunctionDefinitionNS {
  FunctionDefinitionNS(
    create: fn() -> Module,
    public: fn(Module) -> Module,
    with_name: fn(Module, String) -> Module,
    add_parameter: fn(Module, String, Module) -> Module,
    add_untyped_parameter: fn(Module, String) -> Module,
    add_aliased_parameter: fn(Module, String, String, Module) -> Module,
    with_return_type: fn(Module, Module) -> Module,
    add: fn(Module, Module) -> Module,
  )
}

/// Creates a new function definition node.
fn function_definition_node_create() -> Module {
  create_module(
    FunctionDefinition(
      public: False,
      name: None,
      parameters: [],
      return_type: None,
      body: [],
    ),
  )
}

/// Marks the function definition node as public.
fn function_definition_node_public(module: Module) -> Module {
  use node <- modify_module_self(module)

  case node {
    FunctionDefinition(..) -> FunctionDefinition(..node, public: True)
    other -> other
  }
}

/// Sets the name of the function definition node.
fn function_definition_node_with_name(module: Module, name: String) -> Module {
  use node <- modify_module_self(module)

  case node {
    FunctionDefinition(..) -> FunctionDefinition(..node, name: Some(name))
    other -> other
  }
}

/// Adds a typed parameter to the function definition node.
fn function_definition_node_add_parameter(
  module: Module,
  name: String,
  type_: Module,
) -> Module {
  use node, type_ <- modify_module(module, type_)

  case node {
    FunctionDefinition(..) ->
      FunctionDefinition(..node, parameters: [
        FunctionDefinitionParameter(alias: None, name: name, type_: Some(type_)),
        ..node.parameters
      ])
    other -> other
  }
}

/// Adds an untyped parameter to the function definition node.
fn function_definition_node_add_untyped_parameter(
  module: Module,
  name: String,
) -> Module {
  use node <- modify_module_self(module)

  case node {
    FunctionDefinition(..) ->
      FunctionDefinition(..node, parameters: [
        FunctionDefinitionParameter(alias: None, name: name, type_: None),
        ..node.parameters
      ])
    other -> other
  }
}

/// Adds an aliased parameter to the function definition node.
fn function_definition_node_add_aliased_parameter(
  module: Module,
  alias: String,
  name: String,
  type_: Module,
) -> Module {
  use node, type_ <- modify_module(module, type_)

  case node {
    FunctionDefinition(..) ->
      FunctionDefinition(..node, parameters: [
        FunctionDefinitionParameter(
          alias: Some(alias),
          name: name,
          type_: Some(type_),
        ),
        ..node.parameters
      ])
    other -> other
  }
}

/// Sets the return type of the function definition node.
fn function_definition_node_with_return_type(
  module: Module,
  type_: Module,
) -> Module {
  use node, type_ <- modify_module(module, type_)

  case node {
    FunctionDefinition(..) ->
      FunctionDefinition(..node, return_type: Some(type_))
    other -> other
  }
}

/// Adds a node to the body of the function definition node.
fn function_definition_node_add(module: Module, node: Module) -> Module {
  use module, node <- modify_module(module, node)

  case module {
    FunctionDefinition(..) ->
      FunctionDefinition(..module, body: [node, ..module.body])
    other -> other
  }
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                       Binary operation                                        //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// The namespace for the binary operation sub-module.
pub const binop = BinaryOperationNS(
  create: binary_operation_node_create,
  access: binary_operation_node_access,
  pipe: binary_operation_node_pipe,
  string_concat: binary_operation_node_string_concat,
)

/// The type representing the binary operation sub-module namespace.
pub type BinaryOperationNS {
  BinaryOperationNS(
    create: fn(Module, Operator, Module) -> Module,
    access: fn(Module, Module) -> Module,
    pipe: fn(Module, Module) -> Module,
    string_concat: fn(Module, Module) -> Module,
  )
}

/// Creates a new binary operation node.
fn binary_operation_node_create(
  lhs: Module,
  operator: Operator,
  rhs: Module,
) -> Module {
  use lhs, rhs <- modify_module(lhs, rhs)

  BinaryOperation(lhs:, operator:, rhs:)
}

/// Creates a new binary operation node representing an access operation.
fn binary_operation_node_access(lhs: Module, rhs: Module) -> Module {
  binary_operation_node_create(lhs, Access, rhs)
}

/// Creates a new binary operation node representing a pipe operation.
fn binary_operation_node_pipe(lhs: Module, rhs: Module) -> Module {
  binary_operation_node_create(lhs, Pipe, rhs)
}

/// Creates a new binary operation node representing a string concatenation operation.
fn binary_operation_node_string_concat(lhs: Module, rhs: Module) -> Module {
  binary_operation_node_create(lhs, StringConcat, rhs)
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                         Function Call                                         //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// The namespace for the function call sub-module.
pub const function_call = FunctionCallNS(
  create: function_call_node_create,
  add: function_call_node_add,
  add_with_alias: function_call_node_add_with_alias,
)

/// The type representing the function call sub-module namespace.
pub type FunctionCallNS {
  FunctionCallNS(
    create: fn(Module) -> Module,
    add: fn(Module, Module) -> Module,
    add_with_alias: fn(Module, String, Module) -> Module,
  )
}

/// Creates a new function call node.
fn function_call_node_create(lhs: Module) -> Module {
  use lhs <- modify_module_self(lhs)

  FunctionCall(lhs:, parameters: [])
}

/// Adds a parameter to the function call node.
fn function_call_node_add(module: Module, parameter: Module) -> Module {
  use lhs, parameter <- modify_module(module, parameter)

  case lhs {
    FunctionCall(..) ->
      FunctionCall(..lhs, parameters: [
        FunctionCallParameter(alias: None, value: parameter),
        ..lhs.parameters
      ])
    _ -> lhs
  }
}

/// Adds an aliased parameter to the function call node.
fn function_call_node_add_with_alias(
  module: Module,
  alias: String,
  parameter: Module,
) -> Module {
  use lhs, parameter <- modify_module(module, parameter)

  case lhs {
    FunctionCall(..) ->
      FunctionCall(..lhs, parameters: [
        FunctionCallParameter(alias: Some(alias), value: parameter),
        ..lhs.parameters
      ])
    _ -> lhs
  }
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                          Identifier                                           //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// The namespace for the identifier sub-module.
pub const identifier = IdentifierNS(
  create: identifier_node_create,
  discard: Module(imports: [], node: Identifier("_")),
)

/// The type representing the identifier sub-module namespace.
pub type IdentifierNS {
  IdentifierNS(create: fn(String) -> Module, discard: Module)
}

/// Creates a new identifier node.
fn identifier_node_create(name: String) -> Module {
  create_module(Identifier(name))
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                         Builtin Type                                          //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// The namespace for the builtin types sub-module.
pub const types = BuiltinTypesNS(
  string: builtin_type_node_string,
  int: builtin_type_node_int,
  float: builtin_type_node_float,
  bool: builtin_type_node_bool,
)

/// The type representing the builtin types sub-module namespace.
pub type BuiltinTypesNS {
  BuiltinTypesNS(
    string: fn() -> Module,
    int: fn() -> Module,
    float: fn() -> Module,
    bool: fn() -> Module,
  )
}

/// Creates a new builtin type node representing the `String` type.
fn builtin_type_node_string() -> Module {
  identifier_node_create("String")
}

/// Creates a new builtin type node representing the `Int` type.
fn builtin_type_node_int() -> Module {
  identifier_node_create("Int")
}

/// Creates a new builtin type node representing the `Float` type.
fn builtin_type_node_float() -> Module {
  identifier_node_create("Float")
}

/// Creates a new builtin type node representing the `Bool` type.
fn builtin_type_node_bool() -> Module {
  identifier_node_create("Bool")
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Type Definition                                        //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// The namespace for the type definition sub-module.
pub const type_definition = TypeDefinitionNS(
  create: type_definition_node_create,
  public: type_definition_node_public,
  add: type_definition_node_add,
)

/// The type representing the type definition sub-module namespace.
pub type TypeDefinitionNS {
  TypeDefinitionNS(
    create: fn(String) -> Module,
    public: fn(Module) -> Module,
    add: fn(Module, Module) -> Module,
  )
}

/// Creates a new type definition node with the given name.
fn type_definition_node_create(name: String) -> Module {
  create_module(
    TypeDefinition(name: name, public: False, variants: [], generics: []),
  )
}

/// Marks the given type definition node as public.
fn type_definition_node_public(module: Module) -> Module {
  use module <- modify_module_self(module)

  case module {
    TypeDefinition(..) -> TypeDefinition(..module, public: True)
    other -> other
  }
}

/// Adds a variant to the given type definition node.
fn type_definition_node_add(module: Module, variant: Module) -> Module {
  use module, variant <- modify_module(module, variant)

  case module, variant {
    TypeDefinition(..), TypeVariant(variant) ->
      TypeDefinition(..module, variants: [variant, ..module.variants])
    other, _ -> other
  }
}

/// The namespace for the type variant sub-module.
pub const type_variant = TypeVariantNS(
  create: type_variant_node_create,
  field: type_variant_node_field,
)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                         Type Variant                                          //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// The type representing the type variant sub-module namespace.
pub type TypeVariantNS {
  TypeVariantNS(
    create: fn(String) -> Module,
    field: fn(Module, Option(String), Module) -> Module,
  )
}

/// Creates a new type variant node with the given name.
fn type_variant_node_create(name: String) -> Module {
  create_module(TypeVariant(data: TypeVariantData(name: name, fields: [])))
}

/// Adds a field to the given type variant node.
fn type_variant_node_field(
  variant: Module,
  name: Option(String),
  type_: Module,
) -> Module {
  use variant, type_ <- modify_module(variant, type_)

  case variant {
    TypeVariant(data: data) ->
      TypeVariant(
        data: TypeVariantData(name: data.name, fields: [
          Field(name: name, type_: type_),
          ..data.fields
        ]),
      )
    other -> other
  }
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                            Literal                                            //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// The namespace for the literal sub-module.
pub const literal = LiteralNS(
  string: string_node_create,
  int: int_node_create,
  float: float_node_create,
  bool: bool_node_create,
  tuple: tuple_node_create,
  nested_tuple: nested_tuple_node_create,
  list: list_node_create,
  nil: Module(imports: [], node: Identifier("Nil")),
)

/// The type representing the literal sub-module namespace.
pub type LiteralNS {
  LiteralNS(
    string: fn(String) -> Module,
    int: fn(Int) -> Module,
    float: fn(Float) -> Module,
    bool: fn(Bool) -> Module,
    tuple: fn(List(Module)) -> Module,
    nested_tuple: fn(List(Module)) -> Module,
    list: fn(List(Module)) -> Module,
    nil: Module,
  )
}

/// Creates a new string literal node with the given value.
fn string_node_create(value: String) -> Module {
  create_module(Literal(String(value)))
}

/// Creates a new integer literal node with the given value.
fn int_node_create(value: Int) -> Module {
  create_module(Literal(Int(value)))
}

/// Creates a new float literal node with the given value.
fn float_node_create(value: Float) -> Module {
  create_module(Literal(Float(value)))
}

/// Creates a new boolean literal node with the given value.
fn bool_node_create(value: Bool) -> Module {
  create_module(Literal(Bool(value)))
}

/// Creates a new tuple literal node with the given values.
fn tuple_node_create(value: List(Module)) -> Module {
  let module =
    list.fold(value, create_module(Literal(Tuple([]))), fn(module, value) {
      use module, value <- modify_module(module, value)

      case module {
        Literal(Tuple(values)) -> Literal(Tuple([value, ..values]))
        _ -> module
      }
    })

  use node <- modify_module_self(module)

  case node {
    Literal(Tuple(values)) -> Literal(Tuple(list.reverse(values)))
    _ -> node
  }
}

/// Creates a new nested tuple literal node with the given values.
/// 
/// # Example
/// ```gleam
/// nested_tuple_node_create([a, b, c, d])
/// // –––––––––––– Becomes –––––––––––– //
/// [[[a, b], c], d]
/// ```
fn nested_tuple_node_create(value: List(Module)) -> Module {
  let tuple = tuple_node_create(value)
  use node <- modify_module_self(tuple)

  // [a, b, c, d] -> [[[a, b], c] ,d]
  // a -> [a]
  // b -> [a, b]
  // c -> [[a, b], c]

  case node {
    Literal(Tuple(values)) ->
      list.fold(values, Literal(Tuple([])), fn(acc, value) {
        case acc {
          Literal(Tuple([])) -> Literal(Tuple([value]))
          Literal(Tuple([a])) -> Literal(Tuple([a, value]))
          Literal(Tuple([_, _])) -> Literal(Tuple([acc, value]))
          _ -> acc
        }
      })
    _ -> node
  }
}

/// Creates a new list literal node with the given values.
fn list_node_create(value: List(Module)) -> Module {
  list.fold(value, create_module(Literal(List([]))), fn(module, value) {
    use module, value <- modify_module(module, value)

    case module {
      Literal(List(values)) -> Literal(List([value, ..values]))
      _ -> module
    }
  })
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                          Case Branch                                          //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Namespace for creating and manipulating case branch nodes.
pub const case_branch = CaseBranchNS(
  create: case_branch_node_create,
  create_default: case_branch_node_create_default,
  add: case_branch_node_add,
)

/// The type representing the namespace for creating and manipulating case branch nodes.
pub type CaseBranchNS {
  CaseBranchNS(
    create: fn(Module) -> Module,
    create_default: fn() -> Module,
    add: fn(Module, Module) -> Module,
  )
}

/// Adds a new node to the given case branch node.
fn case_branch_node_create(expression: Module) -> Module {
  use expression <- modify_module_self(expression)

  CaseBranch(data: CaseBranchData(expression:, guard: None, body: []))
}

/// Creates a new case branch node with the given expression.
fn case_branch_node_create_default() -> Module {
  create_module(
    CaseBranch(
      data: CaseBranchData(expression: Identifier("_"), guard: None, body: []),
    ),
  )
}

/// Adds a new node to the given case branch node.
fn case_branch_node_add(module: Module, node: Module) -> Module {
  use module, node <- modify_module(module, node)

  case module {
    CaseBranch(data) ->
      CaseBranch(CaseBranchData(..data, body: [node, ..data.body]))
    _ -> module
  }
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Case Expression                                        //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Namespace for creating and manipulating case expression nodes.
pub const case_expression = CaseExpressionNS(
  create: case_expression_node_create,
  add: case_expression_node_add,
)

/// The type representing the namespace for creating and manipulating case expression nodes.
pub type CaseExpressionNS {
  CaseExpressionNS(
    create: fn(Module) -> Module,
    add: fn(Module, Module) -> Module,
  )
}

/// Creates a new case expression node with the given expression and branches.
fn case_expression_node_create(expression: Module) -> Module {
  use expression <- modify_module_self(expression)

  CaseExpression(expression:, branches: [])
}

/// Adds a new branch to the given case expression node.
fn case_expression_node_add(module: Module, branch: Module) -> Module {
  use module, branch <- modify_module(module, branch)

  case module, branch {
    CaseExpression(..), CaseBranch(branch) ->
      CaseExpression(..module, branches: [branch, ..module.branches])
    _, _ -> module
  }
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Use Expression                                         //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Namespace for creating and manipulating use expression nodes.
pub const use_expression = UseExpressionNS(
  create: use_expression_node_create,
  add: use_expression_node_add,
)

/// The type representing the namespace for creating and manipulating use expression nodes.
pub type UseExpressionNS {
  UseExpressionNS(
    create: fn(Module) -> Module,
    add: fn(Module, String) -> Module,
  )
}

/// Creates a new use expression node with the given right-hand side expression.
fn use_expression_node_create(rhs: Module) -> Module {
  use rhs <- modify_module_self(rhs)

  UseExpression(parameters: [], rhs: rhs)
}

/// Adds a new parameter to the given use expression node.
fn use_expression_node_add(module: Module, parameter: String) -> Module {
  use module <- modify_module_self(module)

  case module {
    UseExpression(..) ->
      UseExpression(..module, parameters: [parameter, ..module.parameters])
    _ -> module
  }
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                       Const Definition                                        //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Namespace for creating and manipulating const definition nodes.
pub const const_definition = ConstDefinitionNS(
  create: const_definition_node_create,
  public: const_definition_node_public,
  as_type: const_definition_node_as_type,
)

/// The type representing the namespace for creating and manipulating const definition nodes.
pub type ConstDefinitionNS {
  ConstDefinitionNS(
    create: fn(String, Module) -> Module,
    public: fn(Module) -> Module,
    as_type: fn(Module) -> Module,
  )
}

/// Creates a new const definition node with the given name and value.
fn const_definition_node_create(name: String, module: Module) -> Module {
  use module <- modify_module_self(module)

  ConstDefinition(public: False, as_type: False, name: name, value: module)
}

/// Marks the given const definition node as public.
fn const_definition_node_public(module: Module) -> Module {
  use module <- modify_module_self(module)

  case module {
    ConstDefinition(..) -> ConstDefinition(..module, public: True)
    _ -> module
  }
}

/// Marks the const definition as a type alias.
fn const_definition_node_as_type(module: Module) -> Module {
  use module <- modify_module_self(module)

  case module {
    ConstDefinition(..) -> ConstDefinition(..module, as_type: True)
    _ -> module
  }
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Section Comment                                        //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Creates a new section comment node with the given comment.
pub fn section_comment(comment: String) -> Module {
  create_module(SectionComment(comment: comment))
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Let Definition                                         //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// Namespace for creating and manipulating let definition nodes.
pub const let_definition = LetDefinitionNS(
  create: let_definition_node_create,
  type_: let_definition_node_type,
)

/// The type representing the namespace for creating and manipulating let definition nodes.
pub type LetDefinitionNS {
  LetDefinitionNS(
    create: fn(Module, Module) -> Module,
    type_: fn(Module, Module) -> Module,
  )
}

/// Creates a new let definition node with the given pattern and value.
fn let_definition_node_create(pattern: Module, value: Module) -> Module {
  use pattern, value <- modify_module(pattern, value)

  LetDefinition(pattern: pattern, type_: None, value: value)
}

/// Sets the type of the given let definition node.
fn let_definition_node_type(module: Module, type_: Module) -> Module {
  use module, type_ <- modify_module(module, type_)

  case module {
    LetDefinition(..) -> LetDefinition(..module, type_: Some(type_))
    _ -> module
  }
}
