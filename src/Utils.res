module Array = {
  let setAt = (ar, i, v) => {
    Belt.Array.concatMany([
      Belt.Array.slice(ar, ~offset=0, ~len=i),
      [v],
      Belt.Array.sliceToEnd(ar, i + 1),
    ])
  }

  let append = (ar, a) => Belt.Array.concat(ar, [a])

  let matchBy = (ar: array<'a>, f: 'a => 'b): option<'b> => {
    let match = ar->Belt.Array.reduce(#unknown, (match, item) =>
      switch match {
      | #unknown => #match(item->f)
      | #noMatch => #noMatch
      | #match(matched) => matched == f(item) ? match : #noMatch
      }
    )

    switch match {
    | #match(property) => Some(property)
    | _ => None
    }
  }
}

module Result = {
  let fromOption: (option<'a>, 'e) => result<'a, 'e> = (option, error) => {
    switch option {
    | Some(v) => Ok(v)
    | None => Error(error)
    }
  }

  let toOption: result<'a, 'e> => option<'a> = res =>
    switch res {
    | Ok(v) => Some(v)
    | Error(_) => None
    }

  let mapError: (result<'a, 'e1>, 'e1 => 'e2) => result<'a, 'e2> = (result, map) => {
    switch result {
    | Ok(v) => Ok(v)
    | Error(e) => map(e)->Error
    }
  }
}
