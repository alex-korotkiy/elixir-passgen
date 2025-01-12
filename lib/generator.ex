defmodule Generator do
  @moduledoc """
  Documentation for `Generator`.
  """

  @numeric_range_start 0x30
  @numeric_range_end 0x39

  @numeric_range @numeric_range_start..@numeric_range_end

  @lcase_range_start 0x61
  @lcase_range_end 0x7a

  @lcase_range @lcase_range_start..@lcase_range_end

  @ucase_range_start 0x41
  @ucase_range_end 0x5a

  @ucase_range @ucase_range_start..@ucase_range_end

  @special_range_start1 0x21
  @special_range_end1 0x2f

  @special_range_start2 0x3a
  @special_range_end2 0x40

  @special_range_start3 0x5b
  @special_range_end3 0x60

  @special_range_start4 0x7b
  @special_range_end4 0x7e

  @special_range Enum.concat([@special_range_start1..@special_range_end1, @special_range_start2..@special_range_end2, @special_range_start3..@special_range_end3, @special_range_start4..@special_range_end4])

  @default_min_length 8
  @default_max_length 16
  @default_password_type "chars"

  def iif(expression?, true_part, false_part) do
    case expression? do
      true -> true_part
      _ -> false_part
    end
  end

  def check_numeric?(x) do
    x >= @numeric_range_start && x <= @numeric_range_end
  end

  def check_upper?(x) do
    x >= @ucase_range_start && x <= @ucase_range_end
  end

  def check_special?(x) do
    (x >= @special_range_start1 && x <= @special_range_end1)
    ||
    (x >= @special_range_start2 && x <= @special_range_end2)
    ||
    (x >= @special_range_start3 && x <= @special_range_end3)
    ||
    (x >= @special_range_start4 && x <= @special_range_end4)
  end

  def do_checks_on_enumerable?(enumerable, checks) do
    Enum.all?(
      for check <- checks do
        Enum.any?(enumerable, check)
      end
    )
  end

  def produce_checked(producer, checker) do
    result = producer.()
    if checker.(result) do
      result
    else
      produce_checked(producer, checker)
    end
  end

  def validate_type(type) do
    types = ~w(chars words)
    iif(type not in types, "Invalid type value. Should be 'chars' or 'words'", [])
  end

  def validate_and_balance_lengths(min_length, max_length, chars, rules_count) do

    errors = iif(min_length != nil && min_length <=0, ["Min length should be positive"], [])
    errors = errors ++ iif(max_length != nil && max_length <=0, ["Max length should be positive"], [])

    cond do
      Enum.any?(errors) -> {min_length, max_length, errors, []}

      min_length != nil && max_length !=nil && min_length > max_length -> {min_length, max_length, errors ++ ["Min length should be less or equal to max length"], []}
      max_length !=nil && chars && max_length < rules_count -> {min_length, max_length, errors ++ ["Max length is too small. Should be at least " <> to_string(rules_count) <> " according to number of rules"], []}
      min_length !=nil && chars && min_length < rules_count -> {rules_count, max_length, errors, ["Min length is too small. Should be at least " <> to_string(rules_count) <> " according to number of rules. Increasing min length to " <> to_string(rules_count)]}

      min_length == nil && max_length == nil -> {@default_min_length, @default_max_length, errors, []}
      min_length == nil -> iif(max_length < @default_min_length, {max_length, max_length, errors, []}, {@default_min_length, max_length, errors, []})
      max_length == nil -> iif(min_length > @default_max_length, {min_length, min_length, errors, []}, {min_length, @default_max_length, errors, []})

      true -> {min_length, max_length, errors, []}
    end
  end

  def validate_options(opts) do

    validation_errors = []
    result = []

    type = Keyword.get(opts, :type, @default_password_type)

    validation_errors = validation_errors ++ validate_type(type)

    result = Keyword.put(result, :type, type)
    chars = Keyword.get(result, :type) == "chars"

    uppercase = Keyword.get(opts, :uppercase, false)
    numbers = Keyword.get(opts, :numbers, false)
    symbols = Keyword.get(opts, :symbols, false)

    result = Keyword.put(result, :uppercase, uppercase)
    result = Keyword.put(result, :numbers, numbers)
    result = Keyword.put(result, :symbols, symbols)

    rules_count = iif(uppercase, 1, 0) + iif(numbers, 1, 0) + iif(symbols, 1, 0)

    min_length = Keyword.get(opts, :min_length)
    max_length = Keyword.get(opts, :max_length)

    {min_length, max_length, lv_errors, lv_warnings} = validate_and_balance_lengths(min_length, max_length, chars, rules_count)

    validation_errors = validation_errors ++ lv_errors

    for warning <- lv_warnings do
      IO.puts(warning)
    end

    result = Keyword.put(result, :min_length, min_length)
    result = Keyword.put(result, :max_length, max_length)

    result = Keyword.put(result, :separator, Keyword.get(opts, :separator, "-"))

    cond do
      Enum.empty?(validation_errors) ->
        {:ok, result}
      true ->
        IO.inspect(validation_errors, label: "Validation errors")
        {:error, validation_errors}
    end

  end


  def parse_args(args) do
    {opts, remaining_args, errors} =
      OptionParser.parse(args,
        switches: [
          type: :string,
          min_length: :integer,
          max_length: :integer,
          uppercase: :boolean,
          numbers: :boolean,
          symbols: :boolean,
          separator: :string
        ]
      )

    if Enum.any?(remaining_args) do
      IO.inspect(remaining_args, label: "Warning: unknown options")
    end

    cond do
      Enum.any?(errors) ->
        IO.inspect(errors, label: "Parsing errors")
        {:error, errors}
      true -> validate_options(opts)
    end
  end

  def generate_chars(password_options) do

    min_length = Keyword.get(password_options, :min_length)
    max_length = Keyword.get(password_options, :max_length)
    uppercase = Keyword.get(password_options, :uppercase)
    numbers = Keyword.get(password_options, :numbers)
    symbols = Keyword.get(password_options, :symbols)

    password_length = Enum.random(min_length..max_length)

    {char_range, checks} = {@lcase_range, []}

    {char_range, checks} = iif(uppercase, {Enum.concat(char_range, @ucase_range), Enum.concat(checks, [fn x -> check_upper?(x) end])}, {char_range, checks})

    {char_range, checks} = iif(numbers, {Enum.concat(char_range, @numeric_range), Enum.concat(checks, [fn x -> check_numeric?(x) end])}, {char_range, checks})

    {char_range, checks} = iif(symbols, {Enum.concat(char_range, @special_range), Enum.concat(checks, [fn x -> check_special?(x) end])}, {char_range, checks})

    charlist = Enum.to_list(char_range)

    producer = fn ->
      for _ <- 1..password_length do
        Enum.random(charlist)
      end
    end

    checker = fn x -> do_checks_on_enumerable?(x, checks) end

    produce_checked(producer, checker)
  end

  def random_upper_transform(word) do
    for sym <- String.graphemes(word) do
      iif(Enum.random(0..1)==1, String.upcase(sym), sym)
    end
    |>Enum.join("")
  end

  def generate_words(password_options) do
    dictionary = Words.get_dictionary()

    min_length = Keyword.get(password_options, :min_length)
    max_length = Keyword.get(password_options, :max_length)
    uppercase = Keyword.get(password_options, :uppercase)
    separator = Keyword.get(password_options, :separator)

    password_length = Enum.random(min_length..max_length)

    word_transformer = iif(uppercase,
      fn x -> random_upper_transform(x) end,
      fn x -> x end
    )

    producer = fn ->
      for _ <- 1..password_length do
        Enum.random(dictionary)
      end
      |> Enum.to_list()
      |> Enum.map(word_transformer)
      |> Enum.join(separator)
    end

    checks = iif(uppercase, [fn x -> String.upcase(x) == x end], [])

    checker = fn x -> do_checks_on_enumerable?(String.graphemes(x), checks) end

    produce_checked(producer, checker)
  end

  def generate(password_options) do
    case Keyword.get(password_options, :type, "chars") do
      "chars" -> generate_chars(password_options)
      _ -> generate_words(password_options)
    end
  end

  def main do
    args = System.argv()
    case parse_args(args) do
      {:ok, opts} ->
        IO.puts(generate(opts))
      _ -> IO.puts("Unable to generate password")
    end
  end

end

Generator.main()
