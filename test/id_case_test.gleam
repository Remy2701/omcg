import gleeunit/should
import omcg/id_case

//-----------------------------------------------------------------------------------------------//
//                                       Capitalise First                                        //
//-----------------------------------------------------------------------------------------------//

pub fn capitalise_first_test() {
  assert id_case.capitalise_first("hello") == "Hello"
  assert id_case.capitalise_first("Capitalised") == "Capitalised"
  assert id_case.capitalise_first("CAPITALISED") == "CAPITALISED"
  assert id_case.capitalise_first("cAPITALISED") == "CAPITALISED"
  assert id_case.capitalise_first("") == ""
}

//-----------------------------------------------------------------------------------------------//
//                                        Case Conversion                                        //
//-----------------------------------------------------------------------------------------------//

pub fn string_to_pascal_case_test() {
  assert id_case.string_to_pascal_case("snake_case") == "SnakeCase"
  assert id_case.string_to_pascal_case("camelCase") == "CamelCase"
  assert id_case.string_to_pascal_case("PascalCase") == "PascalCase"
  assert id_case.string_to_pascal_case("UPPER_CASE") == "UPPER_CASE"
  assert id_case.string_to_pascal_case("lowercase") == "Lowercase"
  assert id_case.string_to_pascal_case("") == ""
  assert id_case.string_to_pascal_case("_") == "_"
}

pub fn string_to_snake_case_test() {
  assert id_case.string_to_snake_case("snake_case") == "snake_case"
  assert id_case.string_to_snake_case("camelCase") == "camel_case"
  assert id_case.string_to_snake_case("PascalCase") == "pascal_case"
  assert id_case.string_to_snake_case("UPPER_CASE") == "UPPER_CASE"
  assert id_case.string_to_snake_case("lowercase") == "lowercase"
  assert id_case.string_to_snake_case("") == ""
  assert id_case.string_to_snake_case("_") == "_"
}

//-----------------------------------------------------------------------------------------------//
//                                        Identifier Case                                        //
//-----------------------------------------------------------------------------------------------//

pub fn is_snake_case_test() {
  assert id_case.is_snake_case("snake_case")
  assert !id_case.is_snake_case("snake__case")
  assert id_case.is_snake_case("snake_case123")
  assert !id_case.is_snake_case("camelCase")
  assert !id_case.is_snake_case("PascalCase")
  assert !id_case.is_snake_case("_not_snake_case")
  assert !id_case.is_snake_case("Not_snake_case")
  assert !id_case.is_snake_case("UPPER_SNAKE_CASE")
  assert !id_case.is_snake_case("UPPERCASE")
  assert id_case.is_snake_case("lowercase")
  assert id_case.is_snake_case("")
  assert !id_case.is_snake_case("_")
}

pub fn is_pascal_case_test() {
  assert !id_case.is_pascal_case("snake_case")
  assert !id_case.is_pascal_case("camelCase")
  assert id_case.is_pascal_case("PascalCase")
  assert !id_case.is_pascal_case("Pascal_Case")
  assert id_case.is_pascal_case("ParscalCASE")
  assert id_case.is_pascal_case("PascalCase123")
  assert id_case.is_pascal_case("UPPERCASE")
  assert !id_case.is_pascal_case("UPPER_SNAKE_CASE")
  assert !id_case.is_pascal_case("lowercase")
  assert id_case.is_pascal_case("")
  assert !id_case.is_pascal_case("_")
}

pub fn is_camel_case_test() {
  assert !id_case.is_camel_case("snake_case")
  assert id_case.is_camel_case("camelCase")
  assert !id_case.is_camel_case("PascalCase")
  assert !id_case.is_camel_case("camel_Case")
  assert id_case.is_camel_case("camelCASE")
  assert id_case.is_camel_case("camelCase123")
  assert id_case.is_camel_case("lowercase")
  assert !id_case.is_camel_case("UPPERCASE")
  assert !id_case.is_camel_case("UPPER_SNAKE_CASE")
  assert id_case.is_camel_case("")
  assert !id_case.is_camel_case("_")
}

pub fn identify_case_test() {
  assert id_case.identify_case("snake_case") == id_case.SnakeCase("snake_case")
  assert id_case.identify_case("camelCase") == id_case.CamelCase("camelCase")
  assert id_case.identify_case("PascalCase") == id_case.PascalCase("PascalCase")
  assert id_case.identify_case("UPPER_CASE")
    == id_case.UnknownCase("UPPER_CASE")
  assert id_case.identify_case("lowercase") == id_case.SnakeCase("lowercase")
  assert id_case.identify_case("") == id_case.SnakeCase("")
  assert id_case.identify_case("_") == id_case.UnknownCase("_")
}

//-----------------------------------------------------------------------------------------------//
//                                        Path Utilities                                         //
//-----------------------------------------------------------------------------------------------//

pub fn to_gleam_path_test() {
  "./src/db/user/user_table"
  |> id_case.to_gleam_path
  |> should.equal("db/user/user_table")
}

pub fn to_gleam_path_with_extension_test() {
  "./src/db/user/user_table.surql"
  |> id_case.to_gleam_path
  |> should.equal("db/user/user_table")
}

pub fn namespace_of_test() {
  "./src/db/user/user_table"
  |> id_case.namespace_of
  |> should.equal("user_table")
}

pub fn namespace_of_with_extension_test() {
  "./src/db/user/user_table.surql"
  |> id_case.namespace_of
  |> should.equal("user_table")
}

pub fn without_namespace_test() {
  "user_table.User"
  |> id_case.without_namespace
  |> should.equal("User")
}

pub fn already_without_namespace_test() {
  "User"
  |> id_case.without_namespace
  |> should.equal("User")
}
