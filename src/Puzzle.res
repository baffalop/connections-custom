type connection = {title: string, values: array<string>}
type connections = list<(Group.t, connection)>

let blankRow = {title: "", values: Belt.Array.make(4, "")}
let blankRows = Group.rainbow->List.map(group => (group, blankRow))

let eq = (a, b) => a == b
let getRow = (rows: connections, group: Group.t): connection =>
  List.getAssoc(rows, group, eq)->Option.getExn
let setRow = (rows: connections, group: Group.t, row: connection): connections =>
  List.setAssoc(rows, group, row, eq)
let mapRow = (rows: connections, group: Group.t, f: connection => connection) =>
  setRow(rows, group, getRow(rows, group)->f)

let setValue = (rows: connections, group: Group.t, col: int, value: string) =>
  mapRow(rows, group, row => {
    ...row,
    values: Utils.Array.setAt(row.values, col, value),
  })
let setTitle = (rows: connections, group: Group.t, title: string) =>
  mapRow(rows, group, row => {...row, title})

type cardId = CardId(Group.t, int)

type card = {group: Group.t, id: cardId, value: string}
type cards = array<card>

type solution = {group: Group.t, title: string, values: array<string>}
type solved = array<solution>

let makeCards = (rows: connections): cards => {
  List.toArray(rows)->Belt.Array.flatMap(((group, {values})) =>
    values->Belt.Array.mapWithIndex((i, value) => {
      group,
      id: CardId(group, i),
      value: Js.String.trim(value),
    })
  )
}

let cardKey = (CardId(group, i)) => `${Group.name(group)}-${Belt.Int.toString(i)}`
let groupFromId = (CardId(group, _)) => group

let findSolution = (guess: array<cardId>, connections: connections) => {
  guess
  ->Utils.Array.matchBy(groupFromId)
  ->Option.flatMap(group => {
    connections->List.getAssoc(group, eq)->Option.map(({title, values}) => {group, title, values})
  })
}

module Decode = {
  open Funicular.Decode

  type decodeConnectionsError = [jsonParseError | #Base64ParseError | #Not4Connections]
  type decodeIdError = [jsonParseError | #UnknownGroup]

  let cardId: parser<cardId, decodeIdError> = value => {
    let o = value->object_
    let group =
      o->field("g", v =>
        v
        ->string
        ->Result.flatMap(g => g->Group.fromShortName->Utils.Result.fromOption(#UnknownGroup))
      )
    let index = o->field("i", integer)

    rmap((g, i) => CardId(g, i))->v(group)->v(index)
  }

  let cardIds: parser<array<cardId>, decodeIdError> = array(cardId, _)
  let guesses: parser<array<array<cardId>>, decodeIdError> = array(cardIds, _)

  let cards: parser<array<card>, decodeIdError> = array(value => {
    let o = value->object_
    let id = o->field("id", cardId)
    let name = o->field("v", string)

    rmap((id, name) => {group: groupFromId(id), id, value: name})->v(id)->v(name)
  }, _)

  let connections: parser<connections, decodeConnectionsError> = value => {
    value
    ->array(item => {
      let o = item->object_
      let title = o->field("t", string)
      let values = o->field("v", array(string, _))

      rmap((title, values) => {title, values})->v(title)->v(values)
    }, _)
    ->Result.flatMap(connections => {
      if Belt.Array.length(connections) != 4 {
        Error(#Not4Connections)
      } else {
        connections->List.fromArray->List.zip(Group.rainbow, _)->Ok
      }
    })
  }

  let slug: string => result<connections, decodeConnectionsError> = slug => {
    slug
    ->Base64.decode
    ->Utils.Result.fromOption(#Base64ParseError)
    ->Result.flatMap(parse(_, connections))
  }
}

module Encode = {
  open Funicular.Encode

  let cardId = (CardId(group, i)) =>
    object_([("g", group->Group.shortName->string), ("i", integer(i))])
  let cardIds = array(_, cardId)
  let guesses = array(_, cardIds)
  let cards = array(_, ({id, value}) => object_([("id", cardId(id)), ("v", string(value))]))

  let json = (connections: connections) =>
    connections
    ->List.toArray
    ->array(((_, {title, values})) => object_([("t", string(title)), ("v", array(values, string))]))

  let slug = (connections: connections) => {
    connections->json->Js.Json.stringify->Base64.encode(_, true)
  }
}
