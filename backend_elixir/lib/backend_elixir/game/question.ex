defmodule BackendElixir.Game.Question do
  @moduledoc """
  Question data and utilities for the game.
  """

  @type t :: %{
          id: String.t(),
          text: String.t(),
          options: [String.t()],
          correct_answer: non_neg_integer(),
          correct_answer_context: String.t(),
          time_limit: non_neg_integer()
        }

  @questions [
    %{
      id: "1",
      text: "Qual foi o primeiro exoplaneta confirmado orbitando uma estrela tipo solar, descoberto em 1995 por Mayor e Queloz?",
      options: ["Kepler-22b", "51 Pegasi b", "HD 189733b", "Proxima Centauri b"],
      correct_answer: 1,
      correct_answer_context:
        "51 Pegasi b foi descoberto em 1995 pelos astrônomos Michel Mayor e Didier Queloz usando o método de velocidade radial. Trata-se de um \"Júpiter quente\" que orbita sua estrela em apenas 4,2 dias. A descoberta rendeu o Prêmio Nobel de Física de 2019 aos dois cientistas.",
      time_limit: 20
    },
    %{
      id: "2",
      text: "Qual método de detecção de exoplanetas mede a queda periódica no brilho de uma estrela quando um planeta passa à sua frente?",
      options: ["Velocidade Radial", "Imageamento Direto", "Método de Trânsito", "Microlente Gravitacional"],
      correct_answer: 2,
      correct_answer_context:
        "O método de trânsito detecta exoplanetas pela queda periódica no brilho estelar quando o planeta passa entre a estrela e o observador. É o método mais profícuo: responsável por mais de 75% dos exoplanetas confirmados, incluindo todos os descobertos pelo telescópio Kepler.",
      time_limit: 20
    },
    %{
      id: "3",
      text: "Quantos planetas rochosos foram descobertos no sistema TRAPPIST-1, sendo três deles potencialmente na zona habitável?",
      options: ["4", "5", "7", "9"],
      correct_answer: 2,
      correct_answer_context:
        "O sistema TRAPPIST-1 possui 7 planetas rochosos de tamanho similar à Terra, todos orbitando uma anã ultrafria a apenas 40 anos-luz de nós. Três deles (TRAPPIST-1e, f e g) estão na zona habitável da estrela, tornando este sistema um dos alvos prioritários na busca por vida extraterrestre.",
      time_limit: 20
    },
    %{
      id: "4",
      text: "Qual missão espacial da NASA descobriu mais de 2.600 exoplanetas usando o método de trânsito entre 2009 e 2018?",
      options: ["Hubble", "Kepler", "TESS", "James Webb"],
      correct_answer: 1,
      correct_answer_context:
        "O telescópio espacial Kepler, lançado em 2009, revolucionou a astronomia ao monitorar continuamente ~150.000 estrelas. Em sua missão principal e estendida (K2), confirmou mais de 2.600 exoplanetas e revelou que planetas são fenômenos comuns no universo — estimativas indicam que há pelo menos um planeta por estrela na Via Láctea.",
      time_limit: 20
    },
    %{
      id: "5",
      text: "Em 1992, foram descobertos os primeiros exoplanetas ao redor de que tipo de objeto celular, antecedendo a descoberta de 51 Pegasi b?",
      options: ["Anã branca", "Pulsar", "Anã marrom", "Gigante vermelha"],
      correct_answer: 1,
      correct_answer_context:
        "Aleksander Wolszczan e Dale Frail descobriram em 1992 dois planetas orbitando o pulsar PSR 1257+12, usando variações precisas nos pulsos de rádio. Embora fossem os primeiros exoplanetas confirmados, orbitavam um objeto morto — uma estrela de nêutrons. A descoberta de 51 Pegasi b em 1995 foi o primeiro planeta ao redor de uma estrela como o Sol.",
      time_limit: 20
    },
    %{
      id: "6",
      text: "Qual foi o primeiro exoplaneta a ter sua atmosfera detectada, com identificação de hidrogênio, hélio e carbono?",
      options: ["TRAPPIST-1e", "Proxima Centauri b", "HD 209458b", "Kepler-452b"],
      correct_answer: 2,
      correct_answer_context:
        "HD 209458b, apelidado de \"Osíris\", foi o primeiro exoplaneta com atmosfera detectada, em 2001 pelo telescópio Hubble. Os cientistas identificaram hidrogênio escapando da atmosfera em grande escala, além de carbono e oxigênio. Também foi o primeiro exoplaneta observado em trânsito e o primeiro com mapas de temperatura atmosférica.",
      time_limit: 20
    },
    %{
      id: "7",
      text: "Qual é o exoplaneta mais próximo do Sol, descoberto em 2016 e potencialmente rochoso em zona habitável?",
      options: ["Alpha Centauri Bb", "Proxima Centauri b", "Proxima Centauri c", "Barnard's Star b"],
      correct_answer: 1,
      correct_answer_context:
        "Proxima Centauri b foi descoberto em 2016 orbitando Proxima Centauri, a estrela mais próxima do Sol a 4,2 anos-luz. Com massa mínima de ~1,3 Terras e período orbital de 11 dias, está dentro da zona habitável da anã vermelha. Contudo, a intensa atividade de raios X e flares da estrela levanta dúvidas sobre a habitabilidade real.",
      time_limit: 20
    },
    %{
      id: "8",
      text: "O método de velocidade radial detecta exoplanetas medindo qual fenômeno físico na luz da estrela?",
      options: [
        "A queda periódica de brilho",
        "O efeito Doppler",
        "A curvatura da luz pela gravidade",
        "A emissão de raios X"
      ],
      correct_answer: 1,
      correct_answer_context:
        "O método de velocidade radial (ou espectroscópio Doppler) detecta o \"balanço\" gravitacional que um planeta causa na estrela. Quando o planeta puxa a estrela em nossa direção, as linhas espectrais se deslocam para azul; no sentido oposto, para vermelho. A amplitude do deslocamento revela a massa mínima do planeta.",
      time_limit: 20
    },
    %{
      id: "9",
      text: "Qual telescópio espacial, lançado em 2021, foi o primeiro a detectar CO₂ na atmosfera de um exoplaneta (WASP-39b)?",
      options: ["Hubble", "Spitzer", "Kepler", "James Webb (JWST)"],
      correct_answer: 3,
      correct_answer_context:
        "O Telescópio Espacial James Webb (JWST), lançado em dezembro de 2021, fez a primeira detecção inequívoca de CO₂ na atmosfera de um exoplaneta em agosto de 2022, no Júpiter quente WASP-39b. O JWST também identificou dióxido de enxofre, água e outros compostos, inaugurando uma nova era na caracterização atmosférica de exoplanetas.",
      time_limit: 20
    },
    %{
      id: "10",
      text: "Quantos exoplanetas confirmados existiam no catálogo NASA Exoplanet Archive até o início de 2025?",
      options: ["Mais de 1.000", "Mais de 2.500", "Mais de 5.700", "Mais de 10.000"],
      correct_answer: 2,
      correct_answer_context:
        "O NASA Exoplanet Archive, mantido pelo Instituto de Ciência de Exoplanetas da NASA no Caltech, registrava mais de 5.700 exoplanetas confirmados até 2025, além de milhares de candidatos aguardando confirmação. O catálogo cresce continuamente à medida que novas publicações são aceitas em periódicos científicos revisados por pares.",
      time_limit: 20
    },
    %{
      id: "11",
      text: "Como se chama o fenômeno em que a gravidade de um corpo massivo curva a luz de uma estrela de fundo, podendo revelar exoplanetas?",
      options: ["Efeito Doppler", "Aberração Estelar", "Microlente Gravitacional", "Oscilação Estelar"],
      correct_answer: 2,
      correct_answer_context:
        "A microlente gravitacional ocorre quando um objeto massivo (estrela + eventual planeta) se alinha com uma estrela distante, curvando e amplificando sua luz. Um planeta ao redor da \"lente\" cria uma perturbação adicional no brilho. O método é sensível a planetas de qualquer massa a grandes distâncias da estrela, detectando planetas impossíveis para outros métodos.",
      time_limit: 20
    },
    %{
      id: "12",
      text: "Os \"Júpiteres quentes\" são exoplanetas gigantes gasosos com qual característica orbital marcante?",
      options: [
        "Orbitam muito longe de sua estrela",
        "Têm período orbital muito curto, de poucos dias",
        "São sempre gêmeos de outro planeta",
        "Têm temperatura superficial negativa"
      ],
      correct_answer: 1,
      correct_answer_context:
        "\"Júpiteres quentes\" são gigantes gasosos com massa similar à de Júpiter, mas que orbitam extremamente perto de suas estrelas — com períodos de 1 a 10 dias. Sua temperatura atmosférica pode ultrapassar 2.000 K. 51 Pegasi b foi o primeiro exemplar descoberto. A origem deles é debatida: acredita-se que se formaram longe e migraram para dentro do sistema.",
      time_limit: 20
    },
    %{
      id: "13",
      text: "Qual missão da NASA, lançada em 2018 como sucessora do Kepler, monitora estrelas brilhantes próximas em busca de exoplanetas?",
      options: ["CHEOPS", "PLATO", "TESS", "CoRoT"],
      correct_answer: 2,
      correct_answer_context:
        "O Satélite de Pesquisa de Exoplanetas em Trânsito (TESS), lançado em abril de 2018 a bordo de um Falcon 9, usa quatro câmeras de campo largo para cobrir 85% do céu. Ao contrário do Kepler, foca em estrelas brilhantes próximas (<300 anos-luz), facilitando o acompanhamento por terra. Já confirmou mais de 400 exoplanetas com milhares de candidatos.",
      time_limit: 20
    },
    %{
      id: "14",
      text: "O sistema TRAPPIST-1 está a aproximadamente quantos anos-luz da Terra?",
      options: ["4", "12", "40", "100"],
      correct_answer: 2,
      correct_answer_context:
        "TRAPPIST-1 fica a cerca de 40 anos-luz (12 parsecs) na constelação de Aquário. A estrela central é uma anã ultrafria M8V com luminosidade 0,05% do Sol. O sistema foi descoberto em 1999, mas seus 7 planetas foram anunciados em 2016 (3 planetas) e 2017 (7 planetas) pelo telescópio belga TRAPPIST e pelo Spitzer.",
      time_limit: 20
    },
    %{
      id: "15",
      text: "O que define a \"zona habitável\" de uma estrela também chamada de \"zona de Goldilocks\"?",
      options: [
        "Região onde a temperatura permite água líquida na superfície",
        "Região sem asteroides e cometas",
        "Região com maior concentração de oxigênio",
        "Região protegida pelo campo magnético estelar"
      ],
      correct_answer: 0,
      correct_answer_context:
        "A zona habitável é a faixa orbital onde um planeta rochoso poderia manter água líquida em sua superfície, dada a temperatura da estrela. Não é garantia de habitabilidade — fatores como atmosfera, pressão e campo magnético também importam — mas é o critério inicial para priorizar alvos na busca por vida. O conceito foi formalizado por Kasting et al. em 1993.",
      time_limit: 20
    },
    %{
      id: "16",
      text: "O exoplaneta Kepler-452b foi chamado de \"primo da Terra\" pela NASA em 2015. Qual é seu período orbital aproximado?",
      options: ["10 dias", "100 dias", "385 dias", "700 dias"],
      correct_answer: 2,
      correct_answer_context:
        "Kepler-452b orbita sua estrela em ~385 dias e recebe quantidade de energia semelhante à que a Terra recebe do Sol. Com raio ~1,6 vezes o da Terra, fica na zona habitável de uma estrela tipo G (G2) a ~1.400 anos-luz. Embora seja 60% maior que a Terra, foi o exoplaneta mais parecido com o par Terra-Sol confirmado até 2015.",
      time_limit: 20
    },
    %{
      id: "17",
      text: "O imageamento direto de exoplanetas é o método mais eficaz para detectar qual tipo de planeta?",
      options: [
        "Planetas rochosos próximos à estrela",
        "Planetas gigantes jovens e distantes da estrela",
        "Planetas em zona habitável",
        "Planetas com atmosfera densa de CO₂"
      ],
      correct_answer: 1,
      correct_answer_context:
        "O imageamento direto separa a luz do planeta da luz da estrela bloqueando esta última com um coronógrafo. É mais eficaz para planetas gigantes jovens (ainda quentes e brilhantes em infravermelho) que orbitam longe da estrela. O planeta HR 8799 b (2008) foi um dos primeiros. Para planetas rochosos próximos, o contraste estelar é 10 bilhões de vezes maior que a luz do planeta.",
      time_limit: 20
    },
    %{
      id: "18",
      text: "Qual astrônomo foi pioneiro no método de velocidade radial e propôs em 1952 que seria possível detectar planetas por variações espectrais estelares?",
      options: ["Carl Sagan", "Otto Struve", "Frank Drake", "Giovanni Schiaparelli"],
      correct_answer: 1,
      correct_answer_context:
        "Otto Struve, em 1952, propôs que \"Júpiteres quentes\" orbitando estrelas em períodos curtos poderiam ser detectados pelo efeito Doppler nas linhas espectrais. Na época, a ideia foi ignorada — acreditava-se que planetas gigantes só poderiam existir longe das estrelas, como em nosso sistema solar. A confirmação chegou 43 anos depois com 51 Pegasi b.",
      time_limit: 25
    },
    %{
      id: "19",
      text: "Qual missão europeia, lançada em 2019, mede com precisão os raios de exoplanetas para caracterizar suas densidades e composições?",
      options: ["CoRoT", "CHEOPS", "PLATO", "Gaia"],
      correct_answer: 1,
      correct_answer_context:
        "O CHEOPS (CHaracterising ExOPlanet Satellite) da ESA, lançado em dezembro de 2019, mede com alta precisão os trânsitos de exoplanetas já conhecidos para determinar seus raios com exatidão. Combinando o raio (CHEOPS) com a massa (velocidade radial), calcula-se a densidade bulk, revelando se o planeta é rochoso, oceânico ou gasoso.",
      time_limit: 20
    },
    %{
      id: "20",
      text: "O JWST detectou em 2023 sinais de dimetil sulfeto (DMS) em qual exoplaneta, gerando debate sobre possível origem biológica?",
      options: ["TRAPPIST-1e", "K2-18b", "WASP-39b", "LHS 1140b"],
      correct_answer: 1,
      correct_answer_context:
        "Em setembro de 2023, o JWST detectou evidências de dimetil sulfeto (DMS) na atmosfera de K2-18b, um \"mini-Netuno\" a 120 anos-luz. Na Terra, o DMS é produzido exclusivamente por seres vivos marinhos. O achado é controverso: a detecção está no limiar de significância e pode ter explicações abióticas. É um dos primeiros candidatos a \"biossignatura\" em exoplaneta.",
      time_limit: 25
    }
  ]

  @doc "All questions in the bank, unshuffled, in their internal (snake_case) shape."
  @spec all_questions() :: [t()]
  def all_questions, do: @questions

  @doc "Serializes a question to the camelCase JSON shape the frontend expects."
  @spec serialize(t()) :: map()
  def serialize(q) do
    %{
      id: q.id,
      text: q.text,
      options: q.options,
      correctAnswer: q.correct_answer,
      correctAnswerContext: q.correct_answer_context,
      timeLimit: q.time_limit
    }
  end

  @doc "Drops the correct-answer field from an already-serialized question — safe to send to players before they've answered."
  @spec strip_answer(map() | nil) :: map() | nil
  def strip_answer(nil), do: nil
  def strip_answer(question), do: Map.drop(question, [:correctAnswer])

  @doc "Deals `count` random questions, each with its own options (and correct_answer index) reshuffled."
  @spec get_random(non_neg_integer()) :: [t()]
  def get_random(count \\ 5) do
    @questions
    |> Enum.shuffle()
    |> Enum.take(min(count, length(@questions)))
    |> Enum.map(&shuffle_options/1)
  end

  defp shuffle_options(question) do
    correct_text = Enum.at(question.options, question.correct_answer)
    shuffled = Enum.shuffle(question.options)
    new_correct_index = Enum.find_index(shuffled, fn opt -> opt == correct_text end)

    %{question | options: shuffled, correct_answer: new_correct_index}
  end
end