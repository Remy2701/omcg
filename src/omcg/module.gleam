import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string
import omcg/section_comment

//-----------------------------------------------------------------------------------------------//
//                                           Imports                                             //
//-----------------------------------------------------------------------------------------------//

pub type Import {
  Import(path: List(String), items: List(ImportItem), alias: Option(String))
}

pub type ImportItem {
  ImportType(name: String, alias: Option(String))
  ImportItem(name: String, alias: Option(String))
}

pub fn add_import(module module: Module, path path: List(String)) -> Module {
  Module(..module, imports: [
    Import(path: path, items: [], alias: None),
    ..module.imports
  ])
  |> simplify_imports()
}

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

pub fn merge_imports(a: Module, b: Module) -> Module {
  Module(..a, imports: list.append(a.imports, b.imports))
  |> simplify_imports()
}

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

fn simplify_imports(module: Module) -> Module {
  Module(
    ..module,
    imports: simplify_import_list(module.imports)
      |> list.sort(fn(a: Import, b: Import) {
        string.compare(string.join(a.path, "/"), string.join(b.path, "/"))
      }),
  )
}

//-----------------------------------------------------------------------------------------------//
//                                            Module                                             //
//-----------------------------------------------------------------------------------------------//

pub type Module {
  Module(node: Node, imports: List(Import))
}

fn create_module(node: Node) -> Module {
  Module(node:, imports: [])
}

fn modify_module(
  module: Module,
  other: Module,
  modify: fn(Node, Node) -> Node,
) -> Module {
  Module(..module, node: modify(module.node, other.node))
  |> merge_imports(other)
}

fn modify_module_self(module: Module, modify: fn(Node) -> Node) -> Module {
  Module(..module, node: modify(module.node))
}

pub fn to_string(module: Module) -> String {
  // TODO: Generate imports
  // list.map(module.imports, )
  module.node
  |> node_to_string(0)
}

fn import_to_string(import_: Import) -> String {
  "import "
  <> string.join(import_.path, "/")
  <> case import_.items {
    [] -> ""
    _ ->
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
  <> case import_.alias {
    Some(alias) -> " as " <> alias
    None -> ""
  }
}

pub fn to_string2(module: Module) -> String {
  [
    string.join(list.map(module.imports, import_to_string), "\n"),
    node_to_string(module.node, 0),
  ]
  |> string.join("\n\n")
}

//-----------------------------------------------------------------------------------------------//
//                                             Node                                              //
//-----------------------------------------------------------------------------------------------//

pub type FunctionDefinitionParameter {
  FunctionDefinitionParameter(
    alias: Option(String),
    name: String,
    type_: Option(Node),
  )
}

pub type Operator {
  Access
  Add
  Subtract
  Multiply
  Divide
  FloatAdd
  FloatSubtract
  FloatDivide
  FloatMultiply
  StringConcat
  Pipe
}

pub type FunctionCallParameter {
  FunctionCallParameter(alias: Option(String), value: Node)
}

pub type Field {
  Field(name: Option(String), type_: Node)
}

pub type TypeVariantData {
  TypeVariantData(name: String, fields: List(Field))
}

pub type CaseBranchData {
  CaseBranchData(expression: Node, guard: Option(Node), body: List(Node))
}

pub type Literal {
  String(value: String)
  Int(value: Int)
  Float(value: Float)
  Bool(value: Bool)
  Tuple(value: List(Node))
  List(value: List(Node))
}

pub type Node {
  Root(body: List(Node))
  FunctionDefinition(
    public: Bool,
    name: Option(String),
    parameters: List(FunctionDefinitionParameter),
    return_type: Option(Node),
    body: List(Node),
  )
  BinaryOperation(lhs: Node, operator: Operator, rhs: Node)
  Identifier(name: String)
  FunctionCall(lhs: Node, parameters: List(FunctionCallParameter))
  TypeVariant(data: TypeVariantData)
  TypeDefinition(
    public: Bool,
    name: String,
    generics: List(String),
    variants: List(TypeVariantData),
  )
  ConstDefinition(public: Bool, as_type: Bool, name: String, value: Node)
  CaseBranch(data: CaseBranchData)
  CaseExpression(expression: Node, branches: List(CaseBranchData))
  UseExpression(parameters: List(String), rhs: Node)
  Literal(literal: Literal)
  SectionComment(comment: String)
  LetDefinition(pattern: Node, type_: Option(Node), value: Node)
}

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

//-----------------------------------------------------------------------------------------------//
//                                             Root                                              //
//-----------------------------------------------------------------------------------------------//

pub const root = RootNS(create: root_node_create, add: root_node_add)

pub type RootNS {
  RootNS(create: fn() -> Module, add: fn(Module, Module) -> Module)
}

fn root_node_create() -> Module {
  create_module(Root(body: []))
}

fn root_node_add(module: Module, node: Module) -> Module {
  use module, node <- modify_module(module, node)

  case module, node {
    Root(body:), Root(other_body) -> Root(body: list.append(other_body, body))
    Root(body:), _ -> Root(body: [node, ..body])
    other, _ -> other
  }
}

//-----------------------------------------------------------------------------------------------//
//                                      Function Definition                                      //
//-----------------------------------------------------------------------------------------------//

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

fn function_definition_node_public(module: Module) -> Module {
  use node <- modify_module_self(module)

  case node {
    FunctionDefinition(..) -> FunctionDefinition(..node, public: True)
    other -> other
  }
}

fn function_definition_node_with_name(module: Module, name: String) -> Module {
  use node <- modify_module_self(module)

  case node {
    FunctionDefinition(..) -> FunctionDefinition(..node, name: Some(name))
    other -> other
  }
}

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

fn function_definition_node_add(module: Module, node: Module) -> Module {
  use module, node <- modify_module(module, node)

  case module {
    FunctionDefinition(..) ->
      FunctionDefinition(..module, body: [node, ..module.body])
    other -> other
  }
}

//-----------------------------------------------------------------------------------------------//
//                                       Binary operation                                        //
//-----------------------------------------------------------------------------------------------//

pub const binop = BinaryOperationNS(
  create: binary_operation_node_create,
  access: binary_operation_node_access,
  pipe: binary_operation_node_pipe,
  string_concat: binary_operation_node_string_concat,
)

pub type BinaryOperationNS {
  BinaryOperationNS(
    create: fn(Module, Operator, Module) -> Module,
    access: fn(Module, Module) -> Module,
    pipe: fn(Module, Module) -> Module,
    string_concat: fn(Module, Module) -> Module,
  )
}

fn binary_operation_node_create(
  lhs: Module,
  operator: Operator,
  rhs: Module,
) -> Module {
  use lhs, rhs <- modify_module(lhs, rhs)

  BinaryOperation(lhs:, operator:, rhs:)
}

fn binary_operation_node_access(lhs: Module, rhs: Module) -> Module {
  binary_operation_node_create(lhs, Access, rhs)
}

fn binary_operation_node_pipe(lhs: Module, rhs: Module) -> Module {
  binary_operation_node_create(lhs, Pipe, rhs)
}

fn binary_operation_node_string_concat(lhs: Module, rhs: Module) -> Module {
  binary_operation_node_create(lhs, StringConcat, rhs)
}

//-----------------------------------------------------------------------------------------------//
//                                         Function Call                                         //
//-----------------------------------------------------------------------------------------------//

pub const function_call = FunctionCallNS(
  create: function_call_node_create,
  add: function_call_node_add,
  add_with_alias: function_call_node_add_with_alias,
)

pub type FunctionCallNS {
  FunctionCallNS(
    create: fn(Module) -> Module,
    add: fn(Module, Module) -> Module,
    add_with_alias: fn(Module, String, Module) -> Module,
  )
}

fn function_call_node_create(lhs: Module) -> Module {
  use lhs <- modify_module_self(lhs)

  FunctionCall(lhs:, parameters: [])
}

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

//-----------------------------------------------------------------------------------------------//
//                                          Identifier                                           //
//-----------------------------------------------------------------------------------------------//

pub const identifier = IdentifierNS(
  create: identifier_node_create,
  discard: Module(imports: [], node: Identifier("_")),
)

pub type IdentifierNS {
  IdentifierNS(create: fn(String) -> Module, discard: Module)
}

fn identifier_node_create(name: String) -> Module {
  create_module(Identifier(name))
}

//-----------------------------------------------------------------------------------------------//
//                                         Builtin Type                                          //
//-----------------------------------------------------------------------------------------------//

pub const types = BuiltinTypesNS(
  string: builtin_type_node_string,
  int: builtin_type_node_int,
  float: builtin_type_node_float,
)

pub type BuiltinTypesNS {
  BuiltinTypesNS(
    string: fn() -> Module,
    int: fn() -> Module,
    float: fn() -> Module,
  )
}

fn builtin_type_node_string() -> Module {
  identifier_node_create("String")
}

fn builtin_type_node_int() -> Module {
  identifier_node_create("Int")
}

fn builtin_type_node_float() -> Module {
  identifier_node_create("Float")
}

//-----------------------------------------------------------------------------------------------//
//                                        Type Definition                                        //
//-----------------------------------------------------------------------------------------------//

pub const type_definition = TypeDefinitionNS(
  create: type_definition_node_create,
  public: type_definition_node_public,
  add: type_definition_node_add,
)

pub type TypeDefinitionNS {
  TypeDefinitionNS(
    create: fn(String) -> Module,
    public: fn(Module) -> Module,
    add: fn(Module, Module) -> Module,
  )
}

fn type_definition_node_create(name: String) -> Module {
  create_module(
    TypeDefinition(name: name, public: False, variants: [], generics: []),
  )
}

fn type_definition_node_public(module: Module) -> Module {
  use module <- modify_module_self(module)

  case module {
    TypeDefinition(..) -> TypeDefinition(..module, public: True)
    other -> other
  }
}

fn type_definition_node_add(module: Module, variant: Module) -> Module {
  use module, variant <- modify_module(module, variant)

  case module, variant {
    TypeDefinition(..), TypeVariant(variant) ->
      TypeDefinition(..module, variants: [variant, ..module.variants])
    other, _ -> other
  }
}

pub const type_variant = TypeVariantNS(
  create: type_variant_node_create,
  field: type_variant_node_field,
)

pub type TypeVariantNS {
  TypeVariantNS(
    create: fn(String) -> Module,
    field: fn(Module, Option(String), Module) -> Module,
  )
}

fn type_variant_node_create(name: String) -> Module {
  create_module(TypeVariant(data: TypeVariantData(name: name, fields: [])))
}

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

//-----------------------------------------------------------------------------------------------//
//                                            Literal                                            //
//-----------------------------------------------------------------------------------------------//

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

fn string_node_create(value: String) -> Module {
  create_module(Literal(String(value)))
}

fn int_node_create(value: Int) -> Module {
  create_module(Literal(Int(value)))
}

fn float_node_create(value: Float) -> Module {
  create_module(Literal(Float(value)))
}

fn bool_node_create(value: Bool) -> Module {
  create_module(Literal(Bool(value)))
}

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

fn list_node_create(value: List(Module)) -> Module {
  list.fold(value, create_module(Literal(List([]))), fn(module, value) {
    use module, value <- modify_module(module, value)

    case module {
      Literal(List(values)) -> Literal(List([value, ..values]))
      _ -> module
    }
  })
}

//-----------------------------------------------------------------------------------------------//
//                                        Case Expression                                        //
//-----------------------------------------------------------------------------------------------//

pub const case_branch = CaseBranchNS(
  create: case_branch_node_create,
  create_default: case_branch_node_create_default,
  add: case_branch_node_add,
)

pub type CaseBranchNS {
  CaseBranchNS(
    create: fn(Module) -> Module,
    create_default: fn() -> Module,
    add: fn(Module, Module) -> Module,
  )
}

fn case_branch_node_create(expression: Module) -> Module {
  use expression <- modify_module_self(expression)

  CaseBranch(data: CaseBranchData(expression:, guard: None, body: []))
}

fn case_branch_node_create_default() -> Module {
  create_module(
    CaseBranch(
      data: CaseBranchData(expression: Identifier("_"), guard: None, body: []),
    ),
  )
}

fn case_branch_node_add(module: Module, node: Module) -> Module {
  use module, node <- modify_module(module, node)

  case module {
    CaseBranch(data) ->
      CaseBranch(CaseBranchData(..data, body: [node, ..data.body]))
    _ -> module
  }
}

pub const case_expression = CaseExpressionNS(
  create: case_expression_node_create,
  add: case_expression_node_add,
)

pub type CaseExpressionNS {
  CaseExpressionNS(
    create: fn(Module) -> Module,
    add: fn(Module, Module) -> Module,
  )
}

fn case_expression_node_create(expression: Module) -> Module {
  use expression <- modify_module_self(expression)

  CaseExpression(expression:, branches: [])
}

fn case_expression_node_add(module: Module, branch: Module) -> Module {
  use module, branch <- modify_module(module, branch)

  case module, branch {
    CaseExpression(..), CaseBranch(branch) ->
      CaseExpression(..module, branches: [branch, ..module.branches])
    _, _ -> module
  }
}

//-----------------------------------------------------------------------------------------------//
//                                        Use Expression                                         //
//-----------------------------------------------------------------------------------------------//

pub const use_expression = UseExpressionNS(
  create: use_expression_node_create,
  add: use_expression_node_add,
)

pub type UseExpressionNS {
  UseExpressionNS(
    create: fn(Module) -> Module,
    add: fn(Module, String) -> Module,
  )
}

fn use_expression_node_create(rhs: Module) -> Module {
  use rhs <- modify_module_self(rhs)

  UseExpression(parameters: [], rhs: rhs)
}

fn use_expression_node_add(module: Module, parameter: String) -> Module {
  use module <- modify_module_self(module)

  case module {
    UseExpression(..) ->
      UseExpression(..module, parameters: [parameter, ..module.parameters])
    _ -> module
  }
}

pub fn temptest() {
  root.create()
  |> root.add(
    function_definition.create()
    |> function_definition.with_name("my_function")
    |> function_definition.add(binop.create(
      identifier.create("a"),
      Add,
      identifier.create("b"),
    )),
  )
}

//-----------------------------------------------------------------------------------------------//
//                                       Const Definition                                        //
//-----------------------------------------------------------------------------------------------//

pub const const_definition = ConstDefinitionNS(
  create: const_definition_node_create,
  public: const_definition_node_public,
  as_type: const_definition_node_as_type,
)

pub type ConstDefinitionNS {
  ConstDefinitionNS(
    create: fn(String, Module) -> Module,
    public: fn(Module) -> Module,
    as_type: fn(Module) -> Module,
  )
}

fn const_definition_node_create(name: String, module: Module) -> Module {
  use module <- modify_module_self(module)

  ConstDefinition(public: False, as_type: False, name: name, value: module)
}

fn const_definition_node_public(module: Module) -> Module {
  use module <- modify_module_self(module)

  case module {
    ConstDefinition(..) -> ConstDefinition(..module, public: True)
    _ -> module
  }
}

fn const_definition_node_as_type(module: Module) -> Module {
  use module <- modify_module_self(module)

  case module {
    ConstDefinition(..) -> ConstDefinition(..module, as_type: True)
    _ -> module
  }
}

//-----------------------------------------------------------------------------------------------//
//                                        Section Comment                                        //
//-----------------------------------------------------------------------------------------------//

pub fn section_comment(comment: String) -> Module {
  create_module(SectionComment(comment: comment))
}

//-----------------------------------------------------------------------------------------------//
//                                        Let Definition                                         //
//-----------------------------------------------------------------------------------------------//

pub const let_definition = LetDefinitionNS(
  create: let_definition_node_create,
  type_: let_definition_node_type,
)

pub type LetDefinitionNS {
  LetDefinitionNS(
    create: fn(Module, Module) -> Module,
    type_: fn(Module, Module) -> Module,
  )
}

fn let_definition_node_create(pattern: Module, value: Module) -> Module {
  use pattern, value <- modify_module(pattern, value)

  LetDefinition(pattern: pattern, type_: None, value: value)
}

fn let_definition_node_type(module: Module, type_: Module) -> Module {
  use module, type_ <- modify_module(module, type_)

  case module {
    LetDefinition(..) -> LetDefinition(..module, type_: Some(type_))
    _ -> module
  }
}
