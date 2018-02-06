(**
 * Copyright (c) 2013-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

open Type
open Utils_js
open Reason

exception EDebugThrow of Loc.t
exception EMergeTimeout of float

type invalid_char_set =
  | DuplicateChar of Char.t
  | InvalidChar of Char.t

module InvalidCharSetSet = Set.Make(struct
  type t = invalid_char_set
  let compare = Pervasives.compare
end)

type error_message =
  | EIncompatible of {
      lower: reason * lower_kind option;
      upper: reason * upper_kind;
      use_op: use_op option;
      extras: (int * Reason.t * error_message) list;
    }
  | EIncompatibleDefs of {
      reason_lower: reason;
      reason_upper: reason;
      extras: (int * Reason.t * error_message) list;
    }
  | EIncompatibleProp of {
      prop: string option;
      reason_prop: reason;
      reason_obj: reason;
      special: lower_kind option;
      use_op: use_op option;
    }
  | EDebugPrint of reason * string
  | EImportValueAsType of reason * string
  | EImportTypeAsTypeof of reason * string
  | EImportTypeAsValue of reason * string
  | ENoDefaultExport of reason * string * string option
  | EOnlyDefaultExport of reason * string * string
  | ENoNamedExport of reason * string * string * string option
  | EMissingTypeArgs of { reason_tapp: reason; reason_arity: reason; min_arity: int; max_arity: int }
  | EValueUsedAsType of (reason * reason)
  | EExpectedStringLit of (reason * reason) * string * string Type.literal * use_op
  | EExpectedNumberLit of
      (reason * reason) *
      Type.number_literal *
      Type.number_literal Type.literal *
      use_op
  | EExpectedBooleanLit of (reason * reason) * bool * bool option * use_op
  | EPropNotFound of string option * (reason * reason) * use_op
  | EPropAccess of (reason * reason) * string option * Type.polarity * Type.rw * use_op
  | EPropPolarityMismatch of (reason * reason) * string option * (Type.polarity * Type.polarity) * use_op
  | EPolarityMismatch of {
      reason: reason;
      name: string;
      expected_polarity: Type.polarity;
      actual_polarity: Type.polarity;
    }
  | EStrictLookupFailed of (reason * reason) * reason * string option * use_op option
  | EPrivateLookupFailed of (reason * reason)
  | EAdditionMixed of reason
  | EComparison of (reason * reason)
  | ETupleArityMismatch of (reason * reason) * int * int * use_op
  | ENonLitArrayToTuple of (reason * reason)
  | ETupleOutOfBounds of (reason * reason) * int * int
  | ETupleUnsafeWrite of (reason * reason)
  | EUnionSpeculationFailed of {
      use_op: use_op;
      reason: reason;
      reason_op: reason;
      branches: (int * reason * error_message) list
    }
  | ESpeculationAmbiguous of (reason * reason) * (int * reason) * (int * reason) * reason list
  | EIncompatibleWithExact of (reason * reason) * use_op
  | EUnsupportedExact of (reason * reason)
  | EIdxArity of reason
  | EIdxUse1 of reason
  | EIdxUse2 of reason
  | EUnexpectedThisType of Loc.t
  | EInvalidRestParam of reason
  | ETypeParamArity of Loc.t * int
  | ETypeParamMinArity of Loc.t * int
  | ETooManyTypeArgs of reason * reason * int
  | ETooFewTypeArgs of reason * reason * int
  | EPropertyTypeAnnot of Loc.t
  | EExportsAnnot of Loc.t
  | ECharSetAnnot of Loc.t
  | EInvalidCharSet of { invalid: reason * InvalidCharSetSet.t; valid: reason }
  | EUnsupportedKeyInObjectType of Loc.t
  | EPredAnnot of Loc.t
  | ERefineAnnot of Loc.t
  | EUnexpectedTypeof of Loc.t
  | ECustom of (reason * reason) * string
  | EInternal of Loc.t * internal_error
  | EUnsupportedSyntax of Loc.t * unsupported_syntax
  | EIllegalName of Loc.t
  | EUseArrayLiteral of Loc.t
  | EMissingAnnotation of reason
  | EBindingError of binding_error * Loc.t * string * Scope.Entry.t
  | ERecursionLimit of (reason * reason)
  | EModuleOutsideRoot of Loc.t * string
  | EExperimentalDecorators of Loc.t
  | EExperimentalClassProperties of Loc.t * bool
  | EUnsafeGetSet of Loc.t
  | EExperimentalExportStarAs of Loc.t
  | EIndeterminateModuleType of Loc.t
  | EUnreachable of Loc.t
  | EInvalidObjectKit of { tool: Object.tool; reason: reason; reason_op: reason; use_op: use_op }
  | EInvalidTypeof of Loc.t * string
  | EBinaryInLHS of reason
  | EBinaryInRHS of reason
  | EArithmeticOperand of reason
  | EForInRHS of reason
  | EObjectComputedPropertyAccess of (reason * reason)
  | EObjectComputedPropertyAssign of (reason * reason)
  | EInvalidLHSInAssignment of Loc.t
  | EIncompatibleWithUseOp of reason * reason * use_op
  | EUnsupportedImplements of reason
  | EReactKit of (reason * reason) * React.tool * use_op
  | EReactElementFunArity of reason * string * int
  | EFunctionCallExtraArg of reason * reason * int * use_op
  | EUnsupportedSetProto of reason
  | EDuplicateModuleProvider of {
      module_name: string;
      provider: File_key.t;
      conflict: File_key.t
    }
  | EParseError of Loc.t * Parse_error.t
  | EDocblockError of Loc.t * docblock_error
  (* The string is either the name of a module or "the module that exports `_`". *)
  | EUntypedTypeImport of Loc.t * string
  | EUntypedImport of Loc.t * string
  | ENonstrictImport of Loc.t
  | EUnclearType of Loc.t
  | EUnsafeGettersSetters of Loc.t
  | EUnusedSuppression of Loc.t
  | ELintSetting of LintSettings.lint_parse_error
  | ESketchyNullLint of {
      kind: Lints.sketchy_null_kind;
      loc: Loc.t;
      null_loc: Loc.t;
      falsy_loc: Loc.t;
    }
  | EInvalidPrototype of reason
  | EDeprecatedDeclareExports of Loc.t

and binding_error =
  | ENameAlreadyBound
  | EReferencedBeforeDeclaration
  | ETypeInValuePosition
  | ETypeAliasInValuePosition
  | EConstReassigned
  | EConstParamReassigned
  | EImportReassigned

and docblock_error =
  | MultipleFlowAttributes
  | MultipleProvidesModuleAttributes
  | MultipleJSXAttributes
  | InvalidJSXAttribute of string option

and internal_error =
  | PackageHeapNotFound of string
  | AbnormalControlFlow
  | MethodNotAFunction
  | OptionalMethod
  | OpenPredWithoutSubst
  | PredFunWithoutParamNames
  | UnsupportedGuardPredicate of string
  | BreakEnvMissingForCase
  | PropertyDescriptorPropertyCannotBeRead
  | ForInLHS
  | ForOfLHS
  | InstanceLookupComputed
  | PropRefComputedOpen
  | PropRefComputedLiteral
  | ShadowReadComputed
  | ShadowWriteComputed
  | RestParameterNotIdentifierPattern
  | InterfaceTypeSpread
  | DebugThrow
  | MergeTimeout of float
  | MergeJobException of exn

and unsupported_syntax =
  | ComprehensionExpression
  | GeneratorExpression
  | MetaPropertyExpression
  | ObjectPropertyLiteralNonString
  | ObjectPropertyGetSet
  | ObjectPropertyComputedGetSet
  | InvariantSpreadArgument
  | ClassPropertyLiteral
  | ClassPropertyComputed
  | ReactCreateClassPropertyNonInit
  | RequireDynamicArgument
  | RequireLazyDynamicArgument
  | CatchParameterAnnotation
  | CatchParameterDeclaration
  | DestructuringObjectPropertyLiteralNonString
  | DestructuringExpressionPattern
  | PredicateDeclarationForImplementation
  | PredicateDeclarationWithoutExpression
  | PredicateDeclarationAnonymousParameters
  | PredicateInvalidBody
  | PredicateVoidReturn
  | MultipleIndexers
  | SpreadArgument
  | ImportDynamicArgument

and lower_kind =
  | Possibly_null
  | Possibly_void
  | Possibly_null_or_void
  | Incompatible_intersection

and upper_kind =
  | IncompatibleGetPropT of Loc.t * string option
  | IncompatibleSetPropT of Loc.t * string option
  | IncompatibleGetPrivatePropT
  | IncompatibleSetPrivatePropT
  | IncompatibleMethodT of Loc.t * string option
  | IncompatibleCallT
  | IncompatibleConstructorT
  | IncompatibleGetElemT of Loc.t
  | IncompatibleSetElemT of Loc.t
  | IncompatibleCallElemT of Loc.t
  | IncompatibleElemTOfArrT
  | IncompatibleObjAssignFromTSpread
  | IncompatibleObjAssignFromT
  | IncompatibleObjRestT
  | IncompatibleObjSealT
  | IncompatibleArrRestT
  | IncompatibleSuperT
  | IncompatibleMixinT
  | IncompatibleSpecializeT
  | IncompatibleThisSpecializeT
  | IncompatibleVarianceCheckT
  | IncompatibleGetKeysT
  | IncompatibleHasOwnPropT of Loc.t * string option
  | IncompatibleGetValuesT
  | IncompatibleUnaryMinusT
  | IncompatibleMapTypeTObject
  | IncompatibleTypeAppVarianceCheckT
  | IncompatibleUnclassified of string

let desc_of_reason r = Reason.desc_of_reason ~unwrap:(is_scalar_reason r) r

(* A utility function for getting and updating the use_op in error messages. *)
let util_use_op_of_msg nope util = function
| EIncompatible {use_op; lower; upper; extras} ->
  Option.value_map use_op ~default:nope ~f:(fun use_op ->
    util use_op (fun use_op ->
      EIncompatible {use_op=Some use_op; lower; upper; extras}))
| EIncompatibleProp {use_op; prop; reason_prop; reason_obj; special} ->
  Option.value_map use_op ~default:nope ~f:(fun use_op ->
    util use_op (fun use_op ->
      EIncompatibleProp {use_op=Some use_op; prop; reason_prop; reason_obj; special}))
| EExpectedStringLit (rs, u, l, op) -> util op (fun op -> EExpectedStringLit (rs, u, l, op))
| EExpectedNumberLit (rs, u, l, op) -> util op (fun op -> EExpectedNumberLit (rs, u, l, op))
| EExpectedBooleanLit (rs, u, l, op) -> util op (fun op -> EExpectedBooleanLit (rs, u, l, op))
| EPropNotFound (prop, rs, op) -> util op (fun op -> EPropNotFound (prop, rs, op))
| EPropAccess (rs, prop, p, rw, op) -> util op (fun op -> EPropAccess (rs, prop, p, rw, op))
| EPropPolarityMismatch (rs, p, ps, op) -> util op (fun op -> EPropPolarityMismatch (rs, p, ps, op))
| EStrictLookupFailed (rs, r, p, Some op) ->
  util op (fun op -> EStrictLookupFailed (rs, r, p, Some op))
| ETupleArityMismatch (rs, x, y, op) -> util op (fun op -> ETupleArityMismatch (rs, x, y, op))
| EUnionSpeculationFailed {use_op; reason; reason_op; branches} ->
  util use_op (fun use_op -> EUnionSpeculationFailed {use_op; reason; reason_op; branches})
| EIncompatibleWithExact (rs, op) -> util op (fun op -> EIncompatibleWithExact (rs, op))
| EInvalidObjectKit {tool; reason; reason_op; use_op} ->
  util use_op (fun use_op -> EInvalidObjectKit {tool; reason; reason_op; use_op})
| EIncompatibleWithUseOp (rl, ru, op) -> util op (fun op -> EIncompatibleWithUseOp (rl, ru, op))
| EReactKit (rs, t, op) -> util op (fun op -> EReactKit (rs, t, op))
| EFunctionCallExtraArg (rl, ru, n, op) -> util op (fun op -> EFunctionCallExtraArg (rl, ru, n, op))
| EIncompatibleDefs {reason_lower=_; reason_upper=_; extras=_}
| EDebugPrint (_, _)
| EImportValueAsType (_, _)
| EImportTypeAsTypeof (_, _)
| EImportTypeAsValue (_, _)
| ENoDefaultExport (_, _, _)
| EOnlyDefaultExport (_, _, _)
| ENoNamedExport (_, _, _, _)
| EMissingTypeArgs {reason_tapp=_; reason_arity=_; min_arity=_; max_arity=_}
| EValueUsedAsType (_, _)
| EPolarityMismatch {reason=_; name=_; expected_polarity=_; actual_polarity=_}
| EStrictLookupFailed (_, _, _, None)
| EPrivateLookupFailed (_, _)
| EAdditionMixed (_)
| EComparison (_, _)
| ENonLitArrayToTuple (_, _)
| ETupleOutOfBounds (_, _, _)
| ETupleUnsafeWrite (_, _)
| ESpeculationAmbiguous (_, _, _, _)
| EUnsupportedExact (_, _)
| EIdxArity (_)
| EIdxUse1 (_)
| EIdxUse2 (_)
| EUnexpectedThisType (_)
| EInvalidRestParam (_)
| ETypeParamArity (_, _)
| ETypeParamMinArity (_, _)
| ETooManyTypeArgs (_, _, _)
| ETooFewTypeArgs (_, _, _)
| EPropertyTypeAnnot (_)
| EExportsAnnot (_)
| ECharSetAnnot (_)
| EInvalidCharSet {invalid=_; valid=_}
| EUnsupportedKeyInObjectType (_)
| EPredAnnot (_)
| ERefineAnnot (_)
| EUnexpectedTypeof (_)
| ECustom (_, _)
| EInternal (_, _)
| EUnsupportedSyntax (_, _)
| EIllegalName (_)
| EUseArrayLiteral (_)
| EMissingAnnotation (_)
| EBindingError (_, _, _, _)
| ERecursionLimit (_, _)
| EModuleOutsideRoot (_, _)
| EExperimentalDecorators (_)
| EExperimentalClassProperties (_, _)
| EUnsafeGetSet (_)
| EExperimentalExportStarAs (_)
| EIndeterminateModuleType (_)
| EUnreachable (_)
| EInvalidTypeof (_, _)
| EBinaryInLHS (_)
| EBinaryInRHS (_)
| EArithmeticOperand (_)
| EForInRHS (_)
| EObjectComputedPropertyAccess (_, _)
| EObjectComputedPropertyAssign (_, _)
| EInvalidLHSInAssignment (_)
| EUnsupportedImplements (_)
| EReactElementFunArity (_, _, _)
| EUnsupportedSetProto (_)
| EDuplicateModuleProvider {module_name=_; provider=_; conflict=_}
| EParseError (_, _)
| EDocblockError (_, _)
| EUntypedTypeImport (_, _)
| EUntypedImport (_, _)
| ENonstrictImport (_)
| EUnclearType (_)
| EUnsafeGettersSetters (_)
| EUnusedSuppression (_)
| ELintSetting (_)
| ESketchyNullLint {kind=_; loc=_; null_loc=_; falsy_loc=_}
| EInvalidPrototype (_)
| EDeprecatedDeclareExports (_)
  -> nope

(* Rank scores for signals of different strength on an x^2 scale so that greater
 * signals dominate lesser signals. *)
let reason_score = 100
let frame_score = reason_score * 2
let type_arg_frame_score = frame_score * 2
let tuple_element_frame_score = type_arg_frame_score * 2
let property_sentinel_score = tuple_element_frame_score * 2

(* Gets the score of a use_op. Used in score_of_msg. See the comment on
 * score_of_msg to learn more about scores.
 *
 * Calculated by taking the count of all the frames. *)
let score_of_use_op ~root_use_op use_op =
  let score = fold_use_op
    (* Comparing the scores of use_ops only works when they all have the same
     * root_use_op! If two use_ops have different roots, we can't realistically
     * compare the number of frames since the basis is completely different.
     *
     * So we require a root_use_op to be passed into score_of_use_op and we
     * perform a structural equality check using that.
     *
     * Otherwise, the total score from score_of_use_op is -1. This way, errors
     * which match our root_use_op will be promoted. It is more likely the user
     * was trying to target these branches. *)
    (function
    | use_op when use_op = root_use_op -> Ok 0
    | _ -> Error (-1))

    (fun acc frame -> match acc with Error _ -> acc | Ok acc ->
      Ok (acc + (match frame with
      (* Later params that error get a higher score. This roughly represents how
       * much type-checking work Flow successfully completed before erroring.
       * Useful for basically only overloaded function error messages.
       *
       * The signal that this gives us is that we successfully type checked n
       * params in the call before erroring. If there was no error, Flow may
       * have gone to successfully check another m params. However, we will
       * never know that. n is our best approximation. It rewards errors near
       * the end of a call and punishes (slightly) errors near the beginning of
       * a call.
       *
       * This, however, turns out to be consistent with code style in modern
       * JavaScript. As an unspoken convention, more complex arguments usually
       * go last. For overloaded functions, the switching generally happens on
       * the first argument. The "tag". This gives us confidence that n on
       * FunParam is a good heuristic for the score.
       *
       * FunRestParam is FunParam, but at the end. So give it a larger score
       * then FunParam after adding n.
       *
       * We do _not_ add n to the score if this use_op was added to an implicit type parameter. *)
      | FunParam {n; _} -> frame_score + n
      | FunRestParam _ -> frame_score + frame_score - 1
      (* FunCompatibility is generally followed by another use_op. So let's not
       * count FunCompatibility. *)
      | FunCompatibility _ -> 0
      (* FunMissingArg means the error is *less* likely to be correct. *)
      | FunMissingArg _ -> 0
      (* Higher signal then PropertyCompatibility, for example. *)
      | TypeArgCompatibility _ -> type_arg_frame_score
      (* Higher signal then TypeArgCompatibility. *)
      | TupleElementCompatibility _ -> tuple_element_frame_score
      (* If we error-ed on a sentinel prop compatibility then tank the score of
       * this use_op. This is so that the score of errors which passed sentinel
       * compatibility are always picked relative to the score of errors which
       * failed their sentinel prop checks. *)
      | PropertyCompatibility {is_sentinel=true; _} -> -property_sentinel_score
      | _ -> frame_score)))
    use_op
  in
  match score with
  | Ok n -> n
  | Error n -> n

(* Gets the score of an error message. The score is an approximation of how
 * close the user was to getting their code right. A higher score means the user
 * was closer then a lower score. A score of 0 means we have no signal about
 * how close the user was. For example, consider the following two flows:
 *
 *     number ~> {p: string}
 *
 *     {p: number} ~> {p: string}
 *
 * Clearly, the user was closer to being correct with the second flow. So this
 * function should assign the number ~> string error a higher score then the
 * number ~> object error.
 *
 * Now consider:
 *
 *     number ~> string
 *
 *     number ~> {p: string}
 *
 * This time we kept the lower bound the same and changed the upper bound. The
 * first flow is this time is closer to the user's intent then the second flow.
 * So we give the number ~> string message a higher score then the
 * number ~> object message.
 *
 * This scoring mechanism is useful for union and intersection error messages
 * where we want to approximate which branch the user meant to target with
 * their code. Branches with higher scores have a higher liklihood of being
 * the branch the user was targeting. *)
let score_of_msg ~root_use_op msg =
  (* Start by getting the score based off the use_op of our error message. If
   * the message does not have a use_op then we return 0. This score
   * contribution declares that greater complexity in the use is more likely to
   * cause a match. *)
  let score = util_use_op_of_msg 0 (fun op _ -> score_of_use_op ~root_use_op op) msg in
  (* Special cases for messages which increment the score. *)
  let score = score + match msg with
  (* If a property doesn't exist, we still use a PropertyCompatibility use_op.
   * This PropertyCompatibility when counted in our score is dishonest since
   * a missing prop does not increase the likelihood that the user was close to
   * the right types. *)
  | EIncompatibleProp {use_op=Some (Frame (PropertyCompatibility _, _)); _}
  | EPropNotFound (_, _, Frame (PropertyCompatibility _, _))
  | EStrictLookupFailed (_, _, _, Some (Frame (PropertyCompatibility _, _)))
    -> -frame_score
  | _
    -> 0
  in
  (* If we have two incompatible types and both incompatible types are scalar or
   * both types are arrays then increment our score. This is based on the belief
   * that the solutions with the lowest possible complexity are closest to each
   * other. e.g. number ~> string. If one type is a scalar or array and the
   * other type is not then we decrement our score. *)
  let score = score + (
    let reasons = match msg with
    | EIncompatibleDefs {reason_lower=rl; reason_upper=ru; extras=[]}
    | EIncompatibleWithUseOp (rl, ru, _)
    | EIncompatibleWithExact ((rl, ru), _)
      -> Some (rl, ru)
    | _
      -> None
    in
    match reasons with
    | Some ((rl, ru)) ->
      if is_scalar_reason rl && is_scalar_reason ru then reason_score else
      if is_scalar_reason rl || is_scalar_reason ru then 0 else
      if is_array_reason rl && is_array_reason ru then reason_score else
      if is_array_reason rl || is_array_reason ru then 0 else
      reason_score
    | None ->
      reason_score
  ) in
  score

(* When we are type checking in speculation, we use a root UnknownUse use_op
 * even if when speculation started there was a reasonable root use_op. Once
 * we finish speculation and pick a single error then we want to swap out our
 * true root use_op chain with the UnknownUse used during speculation. This
 * function does that. *)
let add_use_op_to_msg use_op msg =
  util_use_op_of_msg msg (fun use_op' mk_msg ->
    mk_msg (replace_unknown_root_use_op use_op use_op')) msg

(* Decide reason order based on UB's flavor and blamability.
   If the order is unchanged, maintain reference equality. *)
let ordered_reasons ((rl, ru) as reasons) =
  if (is_blamable_reason ru && not (is_blamable_reason rl))
  then ru, rl
  else reasons

let is_useless_op op_reason error_reason =
  match desc_of_reason op_reason with
  | RMethodCall _ -> reasons_overlap op_reason error_reason
  | _ -> false

let rec error_of_msg ?(friendly=true) ~trace_reasons ~source_file =
  let open Errors in

  let mk_info reason extras =
    let desc = string_of_desc (desc_of_reason reason) in
    (* For descriptions that are an identifier wrapped in primes, e.g. `A`, then
     * we want to unwrap the primes and just show A. This looks better in infos.
     * However, when an identifier wrapped with primes is inside some other text
     * then we want to keep the primes since they help with readability. *)
    let desc = if (
      (String.length desc > 2) &&
      ((String.get desc 0) = '`') &&
      ((String.get desc ((String.length desc) - 1)) = '`') &&
      not (String.contains desc ' ')
    ) then (
      String.sub desc 1 ((String.length desc) - 2)
    ) else desc in
    loc_of_reason reason, desc :: extras
  in

  let info_of_reason r = mk_info r [] in

  let trace_infos = List.map info_of_reason trace_reasons in

  let special_suffix = function
    | Some Possibly_null -> " possibly null value"
    | Some Possibly_void -> " possibly undefined value"
    | Some Possibly_null_or_void -> " possibly null or undefined value"
    | Some Incompatible_intersection -> " any member of intersection type"
    | None -> ""
  in

  (* only on use-types - guard calls with is_use t *)
  let err_msg_use special u =
    let msg = match u with
    | IncompatibleGetPropT _ -> "Property cannot be accessed on"
    | IncompatibleGetPrivatePropT -> "Property cannot be accessed on"
    | IncompatibleSetPropT _ -> "Property cannot be assigned on"
    | IncompatibleSetPrivatePropT -> "Property cannot be assigned on"
    | IncompatibleMethodT _ -> "Method cannot be called on"
    | IncompatibleCallT -> "Function cannot be called on"
    | IncompatibleConstructorT -> "Constructor cannot be called on"
    | IncompatibleGetElemT _ -> "Computed property/element cannot be accessed on"
    | IncompatibleSetElemT _ -> "Computed property/element cannot be assigned on"
    | IncompatibleCallElemT _ -> "Computed property/element cannot be called on"
    | IncompatibleElemTOfArrT -> "Element cannot be accessed with"
    | IncompatibleObjAssignFromTSpread -> "Expected array instead of"
    | IncompatibleObjAssignFromT -> "Expected object instead of"
    | IncompatibleObjRestT -> "Expected object instead of"
    | IncompatibleObjSealT -> "Expected object instead of"
    | IncompatibleArrRestT -> "Expected array instead of"
    | IncompatibleSuperT -> "Cannot inherit"
    | IncompatibleMixinT -> "Expected class instead of"
    | IncompatibleSpecializeT -> "Expected polymorphic type instead of"
    | IncompatibleThisSpecializeT -> "Expected class instead of"
    | IncompatibleVarianceCheckT -> "Expected polymorphic type instead of"
    | IncompatibleGetKeysT -> "Expected object instead of"
    | IncompatibleHasOwnPropT _ -> "Property not found in"
    | IncompatibleGetValuesT -> "Expected object instead of"
    | IncompatibleUnaryMinusT -> "Expected number instead of"
    | IncompatibleMapTypeTObject -> "Expected object instead of"
    | IncompatibleTypeAppVarianceCheckT -> "Expected polymorphic type instead of"
    (* unreachable or unclassified use-types. until we have a mechanical way
       to verify that all legit use types are listed above, we can't afford
       to throw on a use type, so mark the error instead *)
    | IncompatibleUnclassified ctor ->
      spf "Type is incompatible with (unclassified use type: %s)" ctor
    in
    spf "%s%s" msg (special_suffix special) in

  let typecheck_error_with_core_infos ?kind ?extra core_msgs =
    let core_reasons = List.map fst core_msgs in
    let core_infos = List.map (fun (r, msgs) -> mk_info r msgs) core_msgs in

    (* Since pointing to endpoints in the library without any information on
       the code that uses those endpoints inconsistently is useless, we point
       to the file containing that code instead. Ideally, improvements in
       error reporting would cause this case to never arise.

       Additionally, we never suppress ops when this happens, because that is
       our last chance at relevant context. *)
    let lib_infos = if List.for_all is_lib_reason core_reasons then
        let loc = Loc.({ none with source = Some source_file }) in
        [loc, ["inconsistent use of library definitions"]]
      else []
    in
    (* main info is core info with optional lib line prepended, and optional
       extra info appended. ops/trace info is held separately in error *)
    let msg_infos = lib_infos @ core_infos in
    mk_error ?kind ~trace_infos ?extra msg_infos
  in

  let typecheck_msgs msg (r1, r2) = [r1, [msg]; r2, []] in

  let typecheck_error msg ?kind ?extra reasons =
    (* make core info from reasons, message, and optional extra infos *)
    let core_msgs = typecheck_msgs msg reasons in
    typecheck_error_with_core_infos ?kind ?extra core_msgs
  in

  let prop_polarity_error_msg x reasons p1 p2 =
    let prop_name = match x with
    | Some x -> spf "property `%s`" x
    | None -> "computed property"
    in
    let reasons' = ordered_reasons reasons in
    let msg =
      if reasons' == reasons then
        spf "%s %s incompatible with %s use in"
          (String.capitalize_ascii (Polarity.string p1))
          prop_name
          (Polarity.string p2)
      else
        spf "Incompatible with %s %s"
          (Polarity.string p1)
          prop_name
    in
    reasons', msg
  in

  let extra_info_of_use_op (rl, ru) extra msg wrapper_msg =
    let infos = [mk_info rl [msg]; mk_info ru []] in
    [InfoNode (
      [Loc.none, [wrapper_msg]],
      [if extra = []
       then InfoLeaf infos
       else InfoNode (infos, extra)]
    )]
  in

  let speculation_extras branches =
    List.map (fun (i, r, msg) ->
      let err = error_of_msg ~friendly:false ~trace_reasons:[] ~source_file msg in
      let header_infos = [
        Loc.none, [spf "Member %d:" (i + 1)];
        info_of_reason r;
        Loc.none, ["Error:"];
      ] in
      let error_infos = infos_of_error err in
      let error_extra = extra_of_error err in
      let info_list = header_infos @ error_infos in
      let info_tree = match error_extra with
        | [] -> Errors.InfoLeaf (info_list)
        | _ -> Errors.InfoNode (info_list, error_extra)
      in
      info_tree
    ) branches
  in

  (* Flip the lower/upper reasons of a frame_use_op. *)
  let flip_frame = function
  | FunCompatibility c -> FunCompatibility {lower = c.upper; upper = c.lower}
  | FunParam c -> FunParam {c with lower = c.upper; upper = c.lower}
  | FunRestParam c -> FunRestParam {lower = c.upper; upper = c.lower}
  | FunReturn c -> FunReturn {lower = c.upper; upper = c.lower}
  | IndexerKeyCompatibility c -> IndexerKeyCompatibility {lower = c.upper; upper = c.lower}
  | PropertyCompatibility c -> PropertyCompatibility {c with lower = c.upper; upper = c.lower}
  | ReactConfigCheck -> ReactConfigCheck
  | TupleElementCompatibility c ->
    TupleElementCompatibility {c with lower = c.upper; upper = c.lower}
  | TypeArgCompatibility c -> TypeArgCompatibility {c with lower = c.upper; upper = c.lower}
  | TypeParamBound _
  | FunMissingArg _
  | ImplicitTypeParam _
  | UnifyFlip
    as use_op -> use_op
  in

  (* Unification produces two errors. One for both sides. For example,
   * {p: number} ~> {p: string} errors on both number ~> string and
   * string ~> number. Showing both errors to our user is often redundant.
   * So we use this utility to flip the string ~> number case and produce an
   * error identical to one we've produced before. These two errors will be
   * deduped in our ErrorSet. *)
  let dedupe_by_flip =
    (* Loop over through the use_op chain. *)
    let rec loop = function
    (* Roots don't flip. *)
    | Op _ as use_op -> (false, use_op)
    (* Start flipping if we are on the reverse side of unification. *)
    | Frame (UnifyFlip, use_op) ->
      let (flip, use_op) = loop use_op in
      (not flip, use_op)
    (* If we are in flip mode then flip our frame. *)
    | Frame (frame, use_op) ->
      let (flip, use_op) = loop use_op in
      if flip
        then (true, Frame (flip_frame frame, use_op))
        else (false, Frame (frame, use_op))
    in
    fun (lower, upper) use_op ->
      let (flip, use_op) = loop use_op in
      if flip
        then ((upper, lower), use_op)
        else ((lower, upper), use_op)
  in

  (* In friendly error messages, we always want to point to a value as the
   * primary location. Or an annotation on a value. Normally, values are found
   * in the lower bound. However, in contravariant positions this flips. In this
   * function we normalize the lower/upper variables in use_ops so that lower
   * always points to the value. Example:
   *
   *     ((x: number) => {}: (x: string) => void);
   *
   * We want to point to number. However, number is in the upper position since
   * number => void ~> string => void flips arguments to string ~> number. This
   * function flips contravariant positions like function arguments back. *)
  let flip_contravariant =
    (* Is this frame part of a contravariant position? *)
    let is_contravariant = function
    | FunParam _, Frame (FunCompatibility _, _) -> (true, true)
    | FunRestParam _, Frame (FunCompatibility _, _) -> (true, true)
    | TypeArgCompatibility {polarity = Negative; _}, _ -> (true, false)
    | _ -> (false, false)
    in
    let is_contravariant_root = function
    | FunImplicitReturn _ -> true
    | _ -> false
    in
    (* Loop through the use_op and flip the contravariants. *)
    let rec loop = function
    | Op root_use_op as use_op -> (is_contravariant_root root_use_op, use_op)
    (* If the frame is contravariant then flip. *)
    | Frame (frame, use_op) ->
      let (flip, use_op) = loop use_op in
      let (contravariant, flip_self) = is_contravariant (frame, use_op) in
      let flip = if contravariant then not flip else flip in
      let flip_self = flip && (not contravariant || flip_self) in
      let frame = if flip_self then flip_frame frame else frame in
      (flip, Frame (frame, use_op))
    in
    fun (lower, upper) use_op ->
      let (flip, use_op) = loop use_op in
      if flip
        then ((upper, lower), use_op)
        else ((lower, upper), use_op)
  in

  (* NB: Some use_ops, like FunReturn, completely replace the `msg` argument.
     Sometimes we call unwrap_use_ops from an error variant that has some
     interesting information in `msg`, like EIncompatibleWithExact. In those
     cases, it's more valuable to preserve the input msg than to replace it.

     To support those cases, callers can pass a `force` argument. A better
     alternative would be to somehow combine the messages, so an exact error
     with a function param would say something like "inexact argument
     incompatible with exact parameter."

     Note that `force` is not recursive, as the input message is consumed by
     `extra_info_of_use_op` and will appear in the output. *)
  let rec unwrap_use_ops ?(force=false) (reasons, extra, msg) = function
  | Frame (PropertyCompatibility {prop=x; lower=rl'; upper=ru'; _}, use_op) ->
    let extra =
      let prop =
        match x with
        | Some "$call" -> "Callable property"
        | None | Some "$key" | Some "$value" -> "Indexable signature"
        | Some x -> spf "Property `%s`" x
      in
      extra_info_of_use_op reasons extra msg
        (spf "%s is incompatible:" prop)
    in
    let obj_reasons = ordered_reasons (rl', ru') in
    let msg = "This type is incompatible with" in
    unwrap_use_ops (obj_reasons, extra, msg) use_op
  | Frame (IndexerKeyCompatibility {lower=rl'; upper=ru'}, use_op) ->
    let extra =
      extra_info_of_use_op reasons extra msg "Indexer key is incompatible:"
    in
    let obj_reasons = ordered_reasons (rl', ru') in
    let msg = "This type is incompatible with" in
    unwrap_use_ops (obj_reasons, extra, msg) use_op
  | Frame (TupleElementCompatibility {n; lower; upper}, use_op) ->
    let extra =
      extra_info_of_use_op reasons extra msg
        (spf "The %s tuple element is incompatible:" (Utils_js.ordinal n))
    in
    let msg = "Has some incompatible tuple element with" in
    unwrap_use_ops ((lower, upper), extra, msg) use_op
  | Frame (TypeArgCompatibility {name=x; lower=reason_op; upper=reason_tapp; _}, use_op) ->
    let extra =
      extra_info_of_use_op reasons extra msg
        (spf "Type argument `%s` is incompatible:" x)
    in
    let msg = "Has some incompatible type argument with" in
    unwrap_use_ops ((reason_op, reason_tapp), extra, msg) use_op
  | Frame (TypeParamBound { name }, use_op) ->
    let msg = spf "This type is incompatible with the bound on type parameter `%s`:" name in
    unwrap_use_ops (reasons, extra, msg) use_op
  | Op FunReturnStatement _ when not force ->
    let msg = "This type is incompatible with the expected return type of" in
    extra, typecheck_msgs msg reasons
  | Op FunImplicitReturn _ when not force ->
    let lreason, ureason = reasons in
    let msg = spf "This type is incompatible with an implicitly-returned %s"
      (string_of_desc (desc_of_reason lreason))
    in
    extra, [ureason, [msg]]
  | Frame (FunParam {lower; _}, Op (FunCall _ | FunCallMethod _)) ->
    let reasons, msg =
      if not force then
        let reasons' = ordered_reasons reasons in
        let msg =
          if reasons' == reasons
          then "This type is incompatible with the expected param type of"
          else "This type is incompatible with an argument type of"
        in
        reasons', msg
      else
        reasons, msg
    in
    (* Always prefer the location from our use_op. use_ops should never have the
     * wrong primary location. *)
    let msgs = if Loc.contains (loc_of_reason lower) (loc_of_reason (fst reasons))
      then typecheck_msgs msg reasons
      else (lower, [])::(typecheck_msgs msg reasons)
    in
    extra, msgs
  | Frame (FunParam {n; _}, Frame (FunCompatibility {lower; upper}, use_op)) ->
    let extra =
      extra_info_of_use_op reasons extra msg
        (spf "The %s parameter is incompatible:" (Utils_js.ordinal n))
    in
    let msg = "This type is incompatible with" in
    unwrap_use_ops ((lower, upper), extra, msg) use_op
  | Frame (FunReturn _, Frame (FunCompatibility {lower; upper}, use_op)) ->
    let extra =
      extra_info_of_use_op reasons extra msg "The return is incompatible:"
    in
    let msg = "This type is incompatible with" in
    unwrap_use_ops ((lower, upper), extra, msg) use_op
  | Frame (FunMissingArg { op; def; _ }, use_op) ->
    let msg = "Too few arguments passed to" in
    unwrap_use_ops ~force:true ((op, def), [], msg) use_op
  | Op (ReactCreateElementCall _) | Op (JSXCreateElement _) ->
    extra, typecheck_msgs msg reasons
  | Op (ReactGetIntrinsic {literal}) ->
    let msg = "Is not a valid React JSX intrinsic" in
    extra, [literal, [msg]]
  | Op (SetProperty {lhs=reason_op; _}) ->
    let rl, ru = reasons in
    let ru = replace_reason_const (desc_of_reason ru) reason_op in
    extra, typecheck_msgs msg (rl, ru)
  | Op (ClassExtendsCheck _) ->
    let msg = if not force
      then "Cannot extend"
      else msg
    in
    extra, typecheck_msgs msg reasons
  | Op (ClassImplementsCheck _) ->
    let msg = if not force
      then "Cannot implement"
      else msg
    in
    extra, typecheck_msgs msg reasons
  (* Passthrough some frame use_ops that don't participate in the
   * error message. *)
  | Frame (FunCompatibility _, use_op)
  | Frame (FunRestParam _, use_op)
  | Frame (ImplicitTypeParam _, use_op)
  | Frame (ReactConfigCheck, use_op)
  | Frame (UnifyFlip, use_op)
    -> unwrap_use_ops ~force (reasons, extra, msg) use_op
  (* Some use_ops always have the definitive location for an error message.
   * When we have one of these use_ops, make sure that its location is always
   * the primary location. *)
  | Op (AssignVar {init=op; _})
  | Op (Cast {lower=op; _})
  | Op (FunCall {op; _})
  | Op (FunCallMethod {op; _})
    ->
    let rl, ru = reasons in
    if Loc.contains (loc_of_reason op) (loc_of_reason rl) then (
      extra, typecheck_msgs msg reasons
    ) else (
      extra, [op, []; rl, [msg]; ru, []]
    )
  | _ ->
    extra, typecheck_msgs msg reasons
  in

  let text = Friendly.text in
  let code = Friendly.code in
  let ref = Friendly.ref in
  let desc = Friendly.ref ~loc:false in

  (* Unwrap a use_op for the friendly error format. Takes the smallest location
   * where we found the error and a use_op which we will unwrap. *)
  let unwrap_use_ops_friendly =
    let open Friendly in
    let rec loop loc frames use_op =
      let action = match use_op with
      | Op UnknownUse
      | Op (Internal _)
        -> `UnknownRoot

      | Op (Addition {op; left; right}) ->
        `Root (op, None,
          [text "Cannot add "; desc left; text " and "; desc right])

      | Op (AssignVar {var; init}) ->
        `Root (init, None, match var with
        | Some var -> [text "Cannot assign "; desc init; text " to "; desc var]
        | None -> [text "Cannot assign "; desc init; text " to variable"])

      | Op Cast {lower; upper} ->
        `Root (lower, None,
          [text "Cannot cast "; desc lower; text " to "; desc upper])

      | Op ClassExtendsCheck {extends; def; _} ->
        `Root (def, None,
          [text "Cannot extend "; ref extends; text " with "; desc def])

      | Op ClassImplementsCheck {implements; def; _} ->
        `Root (def, None,
          [text "Cannot implement "; ref implements; text " with "; desc def])

      | Op Coercion {from; target} ->
        `Root (from, None,
          [text "Cannot coerce "; desc from; text " to "; desc target])

      | Op (FunCall {op; fn; _}) ->
        `Root (op, Some fn, [text "Cannot call "; desc fn])

      | Op (FunCallMethod {op; fn; prop; _}) ->
        `Root (op, Some prop, [text "Cannot call "; desc fn])

      | Frame (FunParam {n; name; lower = lower'; _},
          Op (FunCall {args; fn; _} | FunCallMethod {args; fn; _})) ->
        let lower = if List.length args > n - 1 then List.nth args (n - 1) else lower' in
        let param = match name with
        | Some name -> code name
        | None -> text (spf "the %s parameter" (Utils_js.ordinal n))
        in
        `Root (lower, None,
          [text "Cannot call "; desc fn; text " with "; desc lower; text " bound to "; param])

      | Op (FunReturnStatement {value}) ->
        `Root (value, None,
          [text "Cannot return "; desc value])

      | Op (FunImplicitReturn {upper; fn}) ->
        `Root (upper, None,
          [text "Cannot expect "; desc upper; text " as the return type of "; desc fn])

      | Op (GeneratorYield {value}) ->
        `Root (value, None,
          [text "Cannot yield "; desc value])

      | Op (GetProperty prop) ->
        `Root (prop, None,
          [text "Cannot get "; desc prop])

      | Frame (FunParam _, Op (JSXCreateElement {op; component; _}))
      | Op (JSXCreateElement {op; component; _}) ->
        `Root (op, Some component,
          [text "Cannot create "; desc component; text " element"])

      | Op (ReactCreateElementCall {op; component; _}) ->
        `Root (op, Some component,
          [text "Cannot create "; desc component; text " element"])

      | Op (ReactGetIntrinsic {literal}) ->
        `Root (literal, None,
          [text "Cannot create "; desc literal; text " element"])

      | Op (TypeApplication {type'}) ->
        `Root (type', None,
          [text "Cannot instantiate "; desc type'])

      | Op (SetProperty {prop; value; lhs; _}) ->
        let loc_reason = if Loc.contains (loc_of_reason lhs) loc then lhs else value in
        `Root (loc_reason, None,
          [text "Cannot assign "; desc value; text " to "; desc prop])

      | Frame (FunParam {n; lower; _}, use_op) ->
        `Frame (lower, use_op,
          [text "the "; text (Utils_js.ordinal n); text " argument"])

      | Frame (FunRestParam {lower; _}, use_op) ->
        `Frame (lower, use_op,
          [text "the rest argument"])

      | Frame (FunReturn {lower; _}, use_op) ->
        `Frame (lower, use_op,
          [text "the return value"])

      | Frame (IndexerKeyCompatibility {lower; _}, use_op) ->
        `Frame (lower, use_op,
          [text "the indexer property's key"])

      | Frame (PropertyCompatibility {prop=None | Some "$key" | Some "$value"; lower; _}, use_op) ->
        `Frame (lower, use_op,
          [text "the indexer property"])

      | Frame (PropertyCompatibility {prop=Some "$call"; lower; _}, use_op) ->
        `Frame (lower, use_op,
          [text "the callable signature"])

      | Frame (PropertyCompatibility {prop=Some prop; lower; _}, use_op) ->
        let repos_small_reason loc reason = function
        (* If we are checking class extensions or implementations then the
         * object reason will point to the class name. So don't reposition with
         * this reason. *)
        | Op (ClassExtendsCheck _) ->  repos_reason loc reason
        | Op (ClassImplementsCheck _) ->  repos_reason loc reason
        | _ -> reason
        in
        let lower = repos_small_reason loc lower use_op in
        let rec loop lower = function
        (* Don't match $key/$value/$call properties since they have special
         * meaning. As defined above. *)
        | Frame (PropertyCompatibility {prop=Some prop; lower=lower'; _}, use_op)
            when prop <> "$key" && prop <> "$value" && prop <> "$call" ->
          let lower' = repos_small_reason (loc_of_reason lower) lower' use_op in
          (* Perform the same frame location unwrapping as we do in our
           * general code. *)
          let lower = if Loc.contains (loc_of_reason lower') (loc_of_reason lower)
            then lower else lower' in
          let (lower, props, use_op) = loop lower use_op in
          (lower, prop::props, use_op)
        (* Perform standard iteration through these use_ops. *)
        | use_op -> (lower, [], use_op)
        in
        (* Loop through our parent use_op to get our property path. *)
        let (lower, props, use_op) = loop lower use_op in
        (* Create our final action. *)
        `Frame (lower, use_op,
          [text "property "; code
            (List.fold_left (fun acc prop -> prop ^ "." ^ acc) prop props)])

      | Frame (TupleElementCompatibility {n; lower; _}, use_op) ->
        `Frame (lower, use_op,
          [text "index "; text (string_of_int (n - 1))])

      | Frame (TypeArgCompatibility {name; lower; _}, use_op) ->
        `Frame (lower, use_op,
          [text "type argument "; code name])

      | Frame (TypeParamBound {name}, use_op) ->
        `FrameWithoutLoc (use_op,
          [text "type argument "; code name])

      | Frame (FunCompatibility _, use_op)
      | Frame (FunMissingArg _, use_op)
      | Frame (ImplicitTypeParam _, use_op)
      | Frame (ReactConfigCheck, use_op)
      | Frame (UnifyFlip, use_op)
        -> `Next use_op
      in
      match action with
      (* Skip this use_op and go to the next one. *)
      | `Next use_op -> loop loc frames use_op
      (* Add our frame message and reposition the location if appropriate. *)
      | `Frame (frame_reason, use_op, frame) ->
        (* If our current loc is inside our frame_loc then use our current loc
         * since it is the smallest possible loc in our frame_loc. *)
        let frame_loc = loc_of_reason frame_reason in
        let frame_contains_loc = Loc.contains frame_loc loc in
        let loc = if frame_contains_loc then loc else frame_loc in
        (* Add our frame and recurse with the next use_op. *)
        let (all_frames, local_frames) = frames in
        let frames = (frame::all_frames,
          if frame_contains_loc then local_frames else frame::local_frames) in
        loop loc frames use_op
      (* Same logic as `Frame except we don't have a frame location. *)
      | `FrameWithoutLoc (use_op, frame) ->
        let (all_frames, local_frames) = frames in
        let frames = (frame::all_frames, frame::local_frames) in
        loop loc frames use_op
      (* We don't know what our root is! Return what we do know. *)
      | `UnknownRoot ->
        let (_, local_frames) = frames in
        Some (None, loc, local_frames)
      (* Finish up be returning our root location, root message, primary loc,
       * and frames. *)
      | `Root (root_reason, root_specific_reason, root_message) ->
        (* If our current loc is inside our root_loc then use our current loc
         * since it is the smallest possible loc in our root_loc. *)
        let root_loc = loc_of_reason root_reason in
        let root_specific_loc = Option.map root_specific_reason loc_of_reason in
        let loc = if Loc.contains root_loc loc && Loc.compare root_loc loc <> 0
          then loc
          else Option.value root_specific_loc ~default:root_loc
        in
        (* Return our root loc and message in addition to the true primary loc
         * and frames. *)
        let (all_frames, _) = frames in
        Some (Some (root_loc, root_message), loc, all_frames)
    in
    fun loc use_op message ->
      (* If friendly errors are not turned on then never return a friendly error
       * from this function. *)
      if not friendly then None else
      Option.map (loop loc ([], []) use_op) (fun (root, loc, frames) ->
        (* Construct the message... *)
        let final_message =
          match frames with
          (* If we have no path then it is just the message we were passed. *)
          | [] -> message
          (* Otherwise add the path in sentence format. *)
          | frames ->
            (Inline [Text "in "])::(conjunction_concat ~conjunction:"and then" frames) @
            (if List.length frames > 2 then [Inline [Text "; "]] else [Inline [Text ", "]]) @
            message
        in
        (* Construct the error and return! *)
        match root with
        | Some (root_loc, root_message) ->
          mk_friendly_error_with_root ~trace_infos
            (root_loc, root_message @ [Inline [Text " because"]])
            (loc, final_message)
        | None ->
          mk_friendly_error ~trace_infos loc (capitalize final_message)
      )
  in

  (* An error between two incompatible types. A "lower" type and an "upper"
   * type. The use_op describes the path which we followed to find
   * this incompatibility.
   *
   * This is a specialization of mk_incompatible_use_friendly_error. *)
  let mk_incompatible_friendly_error lower upper use_op =
    let ((lower, upper), use_op) = dedupe_by_flip (lower, upper) use_op in
    let ((lower, upper), use_op) = flip_contravariant (lower, upper) use_op in
    match use_op with
    (* Add a custom message for Coercion root_use_ops that does not include the
     * upper bound. *)
    | Op (Coercion {from; _}) ->
      unwrap_use_ops_friendly (loc_of_reason from) use_op
        [ref lower; text " should not be coerced."]
    (* Ending with FunMissingArg gives us a different error message. Even though
     * this error was generated by an incompatibility, we want to show a more
     * descriptive error message. *)
    | Frame (FunMissingArg { def; op; _ }, use_op) ->
      let message = match use_op with
      | Op (FunCall _ | FunCallMethod _) ->
        let def = replace_reason (function
        | RFunctionType -> RFunction RNormal
        | desc -> desc
        ) def in
        [ref def; text " requires another argument."]
      | _ ->
        [ref def; text " requires another argument from "; ref op; text "."]
      in
      unwrap_use_ops_friendly (loc_of_reason op) use_op message
    | _ ->
      let root_use_op = root_of_use_op use_op in
      (match root_use_op with
      (* Further customize functions with an implicit return. Functions with an
       * implicit return have a lower position which is not valuable. Also
       * clarify that the type was implicitly-returned.
       *
       * In flip_contravariant we flip upper/lower for all FunImplicitReturn. So
       * reverse those back as well. *)
      | FunImplicitReturn {upper=return; _} ->
        unwrap_use_ops_friendly (loc_of_reason lower) use_op (
          [ref lower; text " is incompatible with "] @
          if Loc.compare (loc_of_reason return) (loc_of_reason upper) = 0 then
            [text "implicitly-returned "; desc upper; text "."]
          else
            [ref upper; text "."]
        )
      (* Default incompatibility. *)
      | _ ->
        unwrap_use_ops_friendly (loc_of_reason lower) use_op
          [ref lower; text " is incompatible with "; ref upper; text "."]
      )
  in

  let mk_prop_friendly_message = function
  | None | Some "$key" | Some "$value" -> [text "an indexer property"]
  | Some "$call" -> [text "a callable signature"]
  | Some prop -> [text "property "; code prop]
  in

  (* When we fail to find a property on an object we use this function to create
   * an error. prop_loc should be the position of the use which caused this
   * error. The use_op represents how we got to this error.
   *
   * If the use_op is a PropertyCompatibility frame then we encountered this
   * error while subtyping two objects. In this case we add a bit more
   * information to the error message. *)
  let mk_prop_missing_friendly_error prop_loc prop lower use_op =
    let (loc, lower, upper, use_op) = match use_op with
    (* If we are missing a property while performing property compatibility
     * then we are subtyping. Record the upper reason. *)
    | Frame (PropertyCompatibility {prop=compat_prop; lower; upper; _}, use_op)
        when prop = compat_prop ->
      (loc_of_reason lower, lower, Some upper, use_op)
    (* Otherwise this is a general property missing error. *)
    | _ -> (prop_loc, lower, None, use_op)
    in
    (* If we were subtyping that add to the error message so our user knows what
     * object required the missing property. *)
    let prop_message = mk_prop_friendly_message prop in
    let message = match upper with
    | Some upper ->
      prop_message @ [text " is missing in "; ref lower; text " but exists in "] @
      [ref upper; text "."]
    | None ->
      prop_message @ [text " is missing in "; ref lower; text "."]
    in
    (* Finally, create our error message. *)
    unwrap_use_ops_friendly loc use_op message
  in

  (* An error that occurs when some arbitrary "use" is incompatible with the
   * "lower" type. The use_op describes the path which we followed to find this
   * incompatibility.
   *
   * Similar to mk_incompatible_friendly_error except with any arbitrary *use*
   * instead of specifically an upper type. This error handles all use
   * incompatibilities in general. *)
  let mk_incompatible_use_friendly_error use_loc use_kind lower use_op =
    let nope msg =
      unwrap_use_ops_friendly use_loc use_op
        [ref lower; text (" " ^ msg ^ ".")]
    in
    match use_kind with
    | IncompatibleElemTOfArrT
      -> nope "is not an array index"
    | IncompatibleGetPrivatePropT
    | IncompatibleSetPrivatePropT
      -> nope "is not a class with private properties"
    | IncompatibleCallT
    | IncompatibleConstructorT
      -> nope "is not a function"
    | IncompatibleObjAssignFromTSpread
    | IncompatibleArrRestT
      -> nope "is not an array"
    | IncompatibleObjAssignFromT
    | IncompatibleObjRestT
    | IncompatibleObjSealT
    | IncompatibleGetKeysT
    | IncompatibleGetValuesT
    | IncompatibleMapTypeTObject
      -> nope "is not an object"
    | IncompatibleMixinT
    | IncompatibleThisSpecializeT
      -> nope "is not a class"
    | IncompatibleSpecializeT
    | IncompatibleVarianceCheckT
    | IncompatibleTypeAppVarianceCheckT
      -> nope "is not a polymorphic type"
    | IncompatibleSuperT
      -> nope "is not inheritable"
    | IncompatibleUnaryMinusT
      -> nope "is not a number"
    | IncompatibleGetPropT (prop_loc, prop)
    | IncompatibleSetPropT (prop_loc, prop)
    | IncompatibleHasOwnPropT (prop_loc, prop)
    | IncompatibleMethodT (prop_loc, prop)
      -> mk_prop_missing_friendly_error prop_loc prop lower use_op
    | IncompatibleGetElemT prop_loc
    | IncompatibleSetElemT prop_loc
    | IncompatibleCallElemT prop_loc
      -> mk_prop_missing_friendly_error prop_loc None lower use_op
    (* unreachable or unclassified use-types. until we have a mechanical way
       to verify that all legit use types are listed above, we can't afford
       to throw on a use type, so mark the error instead *)
    | IncompatibleUnclassified ctor
      -> nope (spf "is not supported by unclassified use %s" ctor)
  in

  (* When an object property has a polarity that is incompatible with another
   * error then we create one of these errors. We use terms like "read-only" and
   * "write-only" to better reflect how the user thinks about these properties.
   * Other terminology could include "contravariant", "covariant", and
   * "invariant". Generally these terms are impenatrable to the average
   * JavaScript developer. If we had more documentation explaining these terms
   * it may be fair to use them in error messages. *)
  let mk_prop_polarity_mismatch_friendly_error prop (lower, lpole) (upper, upole) use_op =
    (* Remove redundant PropertyCompatibility if one exists. *)
    let use_op = match use_op with
    | Frame (PropertyCompatibility c, use_op) when c.prop = prop -> use_op
    | _ ->
      use_op
    in
    let expected = match lpole with
    | Positive -> "read-only"
    | Negative -> "write-only"
    | Neutral ->
      (match upole with
      | Negative -> "readable"
      | Positive -> "writable"
      | Neutral -> failwith "unreachable")
    in
    let actual = match upole with
    | Positive -> "read-only"
    | Negative -> "write-only"
    | Neutral ->
      (match lpole with
      | Negative -> "readable"
      | Positive -> "writable"
      | Neutral -> failwith "unreachable")
    in
    unwrap_use_ops_friendly (loc_of_reason lower) use_op (
      mk_prop_friendly_message prop @
      [text (" is " ^ expected ^ " in "); ref lower; text " but "] @
      [text (actual ^ " in "); ref upper; text "."]
    )
  in

  let mk_tuple_arity_mismatch_friendly_error
    (lower, length_lower) (upper, length_upper) use_op =
    unwrap_use_ops_friendly (loc_of_reason lower) use_op [
      ref lower; text (spf " has an arity of %d but " length_lower); ref upper;
      text (spf " has an arity of %d." length_upper);
    ]
  in

  let msg_export export_name =
    if export_name = "default" then
      text "the default export"
    else
      code export_name
  in

  function
  | EIncompatible {
      lower = (reason_lower, lower_kind);
      upper = (reason_upper, upper_kind);
      use_op;
      extras;
    } ->
    (* TODO: friendlify when there are "extras" *)
    let friendly_error = if extras <> []
      then None
      else mk_incompatible_use_friendly_error
        (loc_of_reason reason_upper)
        upper_kind
        reason_lower
        (Option.value ~default:unknown_use use_op)
    in
    (match friendly_error with
    | Some error -> error
    | None ->
      (match use_op with
      | Some use_op ->
        let extra = speculation_extras extras in
        let extra, msgs =
          let msg = err_msg_use lower_kind upper_kind in
          unwrap_use_ops ~force:true ((reason_upper, reason_lower), extra, msg) use_op in
        typecheck_error_with_core_infos ~extra msgs
      | _ ->
        let extra = speculation_extras extras in
        typecheck_error ~extra (err_msg_use lower_kind upper_kind) (reason_upper, reason_lower)
      )
    )

  | EIncompatibleDefs { reason_lower; reason_upper; extras=[] } ->
    (match (mk_incompatible_friendly_error reason_lower reason_upper unknown_use) with
    | Some error -> error
    | None ->
      let reasons = ordered_reasons (reason_lower, reason_upper) in
      typecheck_error "This type is incompatible with" reasons
    )

  (* TODO: friendlify *)
  | EIncompatibleDefs { reason_lower; reason_upper; extras } ->
    let reasons = ordered_reasons (reason_lower, reason_upper) in
    let extra = speculation_extras extras in
    typecheck_error ~extra "This type is incompatible with" reasons

  | EIncompatibleProp { prop; reason_prop; reason_obj; special; use_op } ->
    let friendly_error = mk_prop_missing_friendly_error
      (loc_of_reason reason_prop) prop reason_obj (Option.value ~default:unknown_use use_op) in
    (match friendly_error with
    | Some error -> error
    | None ->
      let reasons = (reason_prop, reason_obj) in
      let msg = spf "Property not found in%s" (special_suffix special) in
      begin match use_op with
      | Some use_op ->
        let extra, msgs = unwrap_use_ops (reasons, [], msg) use_op in
        typecheck_error_with_core_infos ~extra msgs
      | None ->
        typecheck_error msg reasons
      end
    )

  (* TODO: friendlify *)
  | EDebugPrint (r, str) ->
      mk_error ~trace_infos [mk_info r [str]]

  | EImportValueAsType (r, export_name) ->
    mk_friendly_error ~trace_infos (loc_of_reason r) [
      text "Cannot import the value "; msg_export export_name; text " as a type. ";
      code "import type"; text " only works on type exports. Like type aliases, ";
      text "interfaces, and classes. If you intended to import the type of a ";
      text "value use "; code "import typeof"; text " instead.";
    ]

  | EImportTypeAsTypeof (r, export_name) ->
    mk_friendly_error ~trace_infos (loc_of_reason r) [
      text "Cannot import the type "; msg_export export_name; text " as a type. ";
      code "import typeof"; text " only works on value exports. Like variables, ";
      text "functions, and classes. If you intended to import a type use ";
      code "import type"; text " instead.";
    ]

  | EImportTypeAsValue (r, export_name) ->
    mk_friendly_error ~trace_infos (loc_of_reason r) [
      text "Cannot import the type "; msg_export export_name; text " as a value. ";
      text "Use "; code "import type"; text " instead.";
    ]

  | ENoDefaultExport (r, module_name, suggestion) ->
    mk_friendly_error ~trace_infos (loc_of_reason r) (
      [
        text "Cannot import a default export because there is no default export ";
        text "in "; code module_name; text ".";
      ] @
      match suggestion with
      | None -> []
      | Some suggestion -> [text " ";
          text "Did you mean ";
          code (spf "import {%s} from \"%s\"" suggestion module_name);
          text "?";
        ]
    )

  | EOnlyDefaultExport (r, module_name, export_name) ->
    mk_friendly_error ~trace_infos (loc_of_reason r) [
      text "Cannot import "; code export_name; text " because ";
      text "there is no "; code export_name; text " export in ";
      code module_name; text ". Did you mean ";
      code (spf "import %s from \"...\"" export_name); text "?";
    ]

  | ENoNamedExport (r, module_name, export_name, suggestion) ->
    mk_friendly_error ~trace_infos (loc_of_reason r) (
      [
        text "Cannot import "; code export_name; text " because ";
        text "there is no "; code export_name; text " export in ";
        code module_name; text ".";
      ] @
      match suggestion with
      | None -> []
      | Some suggestion -> [text " Did you mean "; code suggestion; text "?"]
    )

  | EMissingTypeArgs { reason_tapp; reason_arity; min_arity; max_arity } ->
    let arity, args =
      if min_arity = max_arity then
        spf "%d" max_arity, if max_arity = 1 then "argument" else "arguments"
      else
        spf "%d-%d" min_arity max_arity, "arguments"
    in
    let reason_arity = replace_reason_const (desc_of_reason reason_tapp) reason_arity in
    mk_friendly_error ~trace_infos (loc_of_reason reason_tapp)
      [text "Cannot use "; ref reason_arity; text (spf " without %s type %s." arity args)]

  | ETooManyTypeArgs (reason_tapp, reason_arity, n) ->
    let reason_arity = replace_reason_const (desc_of_reason reason_tapp) reason_arity in
    mk_friendly_error ~trace_infos (loc_of_reason reason_tapp) [
      text "Cannot use "; ref reason_arity; text " with more than ";
      text (spf "%n type %s." n (if n == 1 then "argument" else "arguments"))
    ]

  | ETooFewTypeArgs (reason_tapp, reason_arity, n) ->
    let reason_arity = replace_reason_const (desc_of_reason reason_tapp) reason_arity in
    mk_friendly_error ~trace_infos (loc_of_reason reason_tapp) [
      text "Cannot use "; ref reason_arity; text " with less than ";
      text (spf "%n type %s." n (if n == 1 then "argument" else "arguments"))
    ]

  | ETypeParamArity (loc, n) ->
    if n = 0 then
      mk_friendly_error ~trace_infos loc
        [text "Cannot apply type because it is not a polymorphic type."]
    else
      mk_friendly_error ~trace_infos loc [
        text "Cannot use type without exactly ";
        text (spf "%n type %s." n (if n == 1 then "argument" else "arguments"));
      ]

  | ETypeParamMinArity (loc, n) ->
    mk_friendly_error ~trace_infos loc [
      text "Cannot use type without at least ";
      text (spf "%n type %s." n (if n == 1 then "argument" else "arguments"));
    ]

  | EValueUsedAsType reasons ->
    let (value, _) = reasons in
    mk_friendly_error ~trace_infos (loc_of_reason value) [
      text "Cannot use "; desc value; text " as a type because ";
      desc value; text " is a value. To get the type of ";
      text "a value use "; code "typeof"; text ".";
    ]

  | EExpectedStringLit (reasons, expected, actual, use_op) ->
    let (reason_lower, reason_upper) = reasons in
    (match (mk_incompatible_friendly_error reason_lower reason_upper use_op) with
    | Some error -> error
    | None ->
      let msg = match actual with
      | Literal (None, actual) ->
          spf "Expected string literal `%s`, got `%s` instead"
            expected actual
      | Truthy | AnyLiteral ->
          spf "Expected string literal `%s`" expected
      | Literal (Some sense, actual) ->
          spf "This %s check always %s because `%s` is not the same string as `%s`"
            (if sense then "===" else "!==")
            (if sense then "fails" else "succeeds")
            actual
            expected
      in
      let extra, msgs =
        unwrap_use_ops ~force:true (reasons, [], msg) use_op in
      typecheck_error_with_core_infos ~extra msgs
    )

  | EExpectedNumberLit (reasons, (expected, _), actual, use_op) ->
    let (reason_lower, reason_upper) = reasons in
    (match (mk_incompatible_friendly_error reason_lower reason_upper use_op) with
    | Some error -> error
    | None ->
      let msg = match actual with
      | Literal (None, (actual, _)) ->
          spf "Expected number literal `%.16g`, got `%.16g` instead"
            expected actual
      | Truthy | AnyLiteral ->
          spf "Expected number literal `%.16g`" expected
      | Literal (Some sense, (actual, _)) ->
          spf "This %s check always %s because `%.16g` is not the same number as `%.16g`"
            (if sense then "===" else "!==")
            (if sense then "fails" else "succeeds")
            actual
            expected
      in
      let extra, msgs =
        unwrap_use_ops ~force:true (reasons, [], msg) use_op in
      typecheck_error_with_core_infos ~extra msgs
    )

  | EExpectedBooleanLit (reasons, expected, actual, use_op) ->
    let (reason_lower, reason_upper) = reasons in
    (match (mk_incompatible_friendly_error reason_lower reason_upper use_op) with
    | Some error -> error
    | None ->
      let msg = match actual with
      | Some actual ->
          spf "Expected boolean literal `%b`, got `%b` instead"
            expected actual
      | None -> spf "Expected boolean literal `%b`" expected
      in
      let extra, msgs =
        unwrap_use_ops ~force:true (reasons, [], msg) use_op in
      typecheck_error_with_core_infos ~extra msgs
    )

  | EPropNotFound (prop, reasons, use_op) ->
    let (reason_prop, reason_obj) = reasons in
    let friendly_error = mk_prop_missing_friendly_error
      (loc_of_reason reason_prop) prop reason_obj use_op in
    (match friendly_error with
    | Some error -> error
    | None ->
      let use_op = match use_op with Op (SetProperty _) -> unknown_use | _ -> use_op in
      let extra, msgs =
        unwrap_use_ops (reasons, [], "Property not found in") use_op in
      typecheck_error_with_core_infos ~extra msgs
    )

  | EPropAccess (reasons, x, polarity, rw, use_op) ->
    let friendly_error =
      let (reason_prop, _) = reasons in
      let rw = match rw with
      | Read -> "readable"
      | Write _ -> "writable"
      in
      unwrap_use_ops_friendly (loc_of_reason reason_prop) use_op
        (mk_prop_friendly_message x @ [text (spf " is not %s." rw)])
    in
    (match friendly_error with
    | Some friendly_error -> friendly_error
    | None ->
      let reasons, msg = prop_polarity_error_msg x reasons polarity (Polarity.of_rw rw) in
      typecheck_error msg reasons
    )

  | EPropPolarityMismatch (reasons, x, (p1, p2), use_op) ->
    let (lreason, ureason) = reasons in
    let friendly_error =
      mk_prop_polarity_mismatch_friendly_error
        x (lreason, p1) (ureason, p2) use_op in
    (match friendly_error with
    | Some friendly_error -> friendly_error
    | None ->
      let reasons, msg = prop_polarity_error_msg x reasons p1 p2 in
      let extra, msgs = unwrap_use_ops (reasons, [], msg) use_op in
      typecheck_error_with_core_infos ~extra msgs
    )

  (* TODO: friendlify *)
  | EPolarityMismatch { reason; name; expected_polarity; actual_polarity } ->
      mk_error ~trace_infos [mk_info reason [spf
        "%s position (expected `%s` to occur only %sly)"
        (Polarity.string actual_polarity)
        name
        (Polarity.string expected_polarity)]]

  | EStrictLookupFailed (reasons, lreason, x, use_op) ->
    (* if we're looking something up on the global/builtin object, then tweak
       the error to say that `x` doesn't exist. We can tell this is the
       global object because that should be the only object created with
       `builtin_reason` instead of an actual location (see `Init_js.init`). *)
    if is_builtin_reason lreason then
      let (reason, _) = reasons in
      let msg = match x with
      | Some x when is_internal_module_name x ->
        [text "Cannot resolve module "; code (uninternal_module_name x); text "."]
      | None -> [text "Cannot resolve name "; desc reason; text "."]
      | Some x when is_internal_name x -> [text "Cannot resolve name "; desc reason; text "."]
      | Some x -> [text "Cannot resolve name "; code x; text "."]
      in
      mk_friendly_error ~trace_infos (loc_of_reason reason) msg
    else
      let (reason_prop, reason_obj) = reasons in
      let friendly_error =
        mk_prop_missing_friendly_error
          (loc_of_reason reason_prop) x reason_obj (Option.value ~default:unknown_use use_op)
      in
      (match friendly_error with
      | Some error -> error
      | None ->
        let msg = match x with
        | Some "$call" -> "Callable signature not found in"
        | Some "$key" | Some "$value" -> "Indexable signature not found in"
        | _ -> "Property not found in"
        in
        begin match use_op with
        | Some use_op ->
          let use_op = match use_op with Op (SetProperty _) -> unknown_use | _ -> use_op in
          let extra, msgs =
            unwrap_use_ops ~force:true (reasons, [], msg) use_op in
          typecheck_error_with_core_infos ~extra msgs
        | None ->
          typecheck_error msg reasons
        end
      )

  (* TODO: friendlify *)
  | EPrivateLookupFailed reasons ->
      typecheck_error "Property not found in" reasons

  (* TODO: friendlify *)
  | EAdditionMixed reason ->
      mk_error ~trace_infos [mk_info reason [
        "This type cannot be used in an addition because it is unknown \
         whether it behaves like a string or a number."]]

  (* TODO: friendlify *)
  | EComparison reasons ->
      typecheck_error "This type cannot be compared to" reasons

  | ETupleArityMismatch (reasons, l1, l2, use_op) ->
    let (lreason, ureason) = reasons in
    let friendly_error =
      mk_tuple_arity_mismatch_friendly_error
        (lreason, l1) (ureason, l2) use_op
    in
    (match friendly_error with
    | Some friendly_error -> friendly_error
    | None ->
      let msg = spf
        "Tuple arity mismatch. This tuple has %d elements and cannot flow to \
        the %d elements of"
        l1
        l2 in
      let extra, msgs =
        unwrap_use_ops ~force:true (reasons, [], msg) use_op
      in
      typecheck_error_with_core_infos ~extra msgs
    )

  (* TODO: friendlify *)
  | ENonLitArrayToTuple reasons ->
      let msg =
        "Only tuples and array literals with known elements can flow to" in
      typecheck_error msg reasons

  (* TODO: friendlify *)
  | ETupleOutOfBounds (reasons, length, index) ->
      let msg = spf
        "Out of bound access. This tuple has %d elements and you tried to \
        access index %d of"
        length
        index in
      typecheck_error msg reasons

  (* TODO: friendlify *)
  | ETupleUnsafeWrite (reasons) ->
      let msg = spf
        "Flow will only let you modify a tuple if it knows exactly which \
        element of the tuple you are mutating. Unsafe mutation of" in
      typecheck_error msg reasons

  (* TODO: friendlify *)
  | EUnionSpeculationFailed { use_op; reason; reason_op; branches } ->
      let extra, msgs =
        let reasons = ordered_reasons (reason, reason_op) in
        let extra = speculation_extras branches in
        let msg = "This type is incompatible with" in
        unwrap_use_ops (reasons, extra, msg) use_op
      in
      typecheck_error_with_core_infos ~extra msgs

  (* TODO: friendlify *)
  | ESpeculationAmbiguous ((case_r, r), (prev_i, prev_case), (i, case), case_rs) ->
      let infos = List.map info_of_reason case_rs in
      let extra = [
        InfoLeaf [
          Loc.none, [spf "Case %d may work:" (prev_i + 1)];
          info_of_reason prev_case;
        ];
        InfoLeaf [
          Loc.none, [spf
            "But if it doesn't, case %d looks promising too:"
            (i + 1)];
          info_of_reason case;
        ];
        InfoLeaf (
          (Loc.none, [spf
            "Please provide additional annotation(s) to determine whether \
             case %d works (or consider merging it with case %d):"
            (prev_i + 1)
            (i + 1)]
          )::infos
        )
      ] in
      mk_error ~trace_infos ~extra [
        (mk_info case_r ["Could not decide which case to select"]);
        (info_of_reason r)
      ]

  | EIncompatibleWithExact (reasons, use_op) ->
    let (lower, upper) = reasons in
    let friendly_error =
      unwrap_use_ops_friendly (loc_of_reason lower) use_op
        [text "inexact "; ref lower; text " is incompatible with exact "; ref upper; text "."]
    in
    (match friendly_error with
    | Some friendly_error -> friendly_error
    | None ->
      let msg = "Inexact type is incompatible with exact type" in
      let extra, msgs =
        unwrap_use_ops ~force:true (reasons, [], msg) use_op
      in
      typecheck_error_with_core_infos ~extra msgs
    )

  (* TODO: friendlify *)
  | EUnsupportedExact reasons ->
      typecheck_error "Unsupported exact type" reasons

  (* TODO: friendlify *)
  | EIdxArity reason ->
      mk_error ~trace_infos [mk_info reason [
        "idx() function takes exactly two params!"
      ]]

  (* TODO: friendlify *)
  | EIdxUse1 reason ->
      mk_error ~trace_infos [mk_info reason [
        "idx() callback functions may not be annotated and they may only \
         access properties on the callback parameter!"
      ]]

  (* TODO: friendlify *)
  | EIdxUse2 reason ->
      mk_error ~trace_infos [mk_info reason [
        "idx() callbacks may only access properties on the callback \
         parameter!"
      ]]

  (* TODO: friendlify *)
  | EUnexpectedThisType loc ->
      mk_error ~trace_infos [loc, ["Unexpected use of `this` type"]]

  (* TODO: friendlify *)
  | EInvalidRestParam reason ->
      mk_error ~trace_infos ~kind:InferWarning [mk_info reason [
        "rest parameter should have an array type"
      ]]

  (* TODO: friendlify *)
  | EPropertyTypeAnnot loc ->
      let msg =
        "expected object type and string literal as arguments to \
         $PropertyType"
      in
      mk_error ~trace_infos [loc, [msg]]

  (* TODO: friendlify *)
  | EExportsAnnot loc ->
      mk_error ~trace_infos [loc, ["$Exports requires a string literal"]]

  (* TODO: friendlify *)
  | ECharSetAnnot loc ->
      mk_error ~trace_infos [loc, ["$CharSet requires a string literal"]]

  (* TODO: friendlify *)
  | EInvalidCharSet {
      invalid = (invalid_reason, invalid_chars);
      valid = valid_reason;
    } ->
      let def_loc = def_loc_of_reason invalid_reason in
      let extra =
        InvalidCharSetSet.fold (fun c acc ->
          match c with
          | InvalidChar c -> InfoLeaf [def_loc, [spf "`%c` is not a member of the set" c]]::acc
          | DuplicateChar c -> InfoLeaf [def_loc, [spf "`%c` is duplicated" c]]::acc
        ) invalid_chars []
        |> List.rev
      in
      mk_error ~trace_infos ~extra [
        mk_info invalid_reason ["This type is incompatible with"];
        mk_info valid_reason [];
      ]

  (* TODO: friendlify *)
  | EUnsupportedKeyInObjectType loc ->
      mk_error ~trace_infos [loc, ["Unsupported key in object type"]]

  (* TODO: friendlify *)
  | EPredAnnot loc ->
      let msg =
        "expected number of refined variables (currently only supporting \
         one variable)"
      in
      mk_error ~trace_infos [loc, [msg]]

  (* TODO: friendlify *)
  | ERefineAnnot loc ->
      let msg =
        "expected base type and predicate type as arguments to $Refine"
      in
      mk_error ~trace_infos [loc, [msg]]

  | EUnexpectedTypeof loc ->
    mk_friendly_error ~trace_infos ~kind:InferWarning loc
      [code "typeof"; text " can only be used to get the type of variables."]

  (* TODO: friendlify *)
  | ECustom (reasons, msg) ->
      typecheck_error msg reasons

  (* TODO: friendlify *)
  | EInternal (loc, internal_error) ->
      let msg = match internal_error with
      | PackageHeapNotFound pkg ->
          spf "Package %S was not found in the PackageHeap!" pkg
      | AbnormalControlFlow ->
          "abnormal control flow"
      | MethodNotAFunction ->
          "expected function type"
      | OptionalMethod ->
          "optional methods are not supported"
      | OpenPredWithoutSubst ->
          "OpenPredT ~> OpenPredT without substitution"
      | PredFunWithoutParamNames ->
          "FunT -> FunT no params"
      | UnsupportedGuardPredicate pred ->
          spf "Unsupported guard predicate (%s)" pred
      | BreakEnvMissingForCase ->
          "break env missing for case"
      | PropertyDescriptorPropertyCannotBeRead ->
          "Unexpected property in properties object"
      | ForInLHS ->
          "unexpected LHS in for...in"
      | ForOfLHS ->
          "unexpected LHS in for...of"
      | InstanceLookupComputed ->
          "unexpected computed property lookup on InstanceT"
      | PropRefComputedOpen ->
          "unexpected open computed property element type"
      | PropRefComputedLiteral ->
          "unexpected literal computed property element type"
      | ShadowReadComputed ->
          "unexpected shadow read on computed property"
      | ShadowWriteComputed ->
          "unexpected shadow write on computed property"
      | RestParameterNotIdentifierPattern ->
          "unexpected rest parameter, expected an identifier pattern"
      | InterfaceTypeSpread ->
          "unexpected spread property in interface"
      | DebugThrow ->
          "debug throw"
      | MergeTimeout s ->
          spf "merge job timed out after %0.2f seconds" s
      | MergeJobException exc ->
          "uncaught exception: "^(Utils_js.fmt_exc exc)
      in
      mk_error ~trace_infos ~kind:InternalError [loc, [
        spf "Internal error: %s" msg
      ]]

  (* TODO: friendlify *)
  | EUnsupportedSyntax (loc, unsupported_syntax) ->
      let msg = match unsupported_syntax with
        | ComprehensionExpression
        | GeneratorExpression
        | MetaPropertyExpression ->
            "not (sup)ported"
        | ObjectPropertyLiteralNonString ->
            "non-string literal property keys not supported"
        | ObjectPropertyGetSet ->
            "get/set properties not yet supported"
        | ObjectPropertyComputedGetSet ->
            "computed getters and setters are not yet supported"
        | InvariantSpreadArgument ->
            "unsupported arguments in call to invariant()"
        | ClassPropertyLiteral ->
            "literal properties not yet supported"
        | ClassPropertyComputed ->
            "computed property keys not supported"
        | ReactCreateClassPropertyNonInit ->
            "unsupported property specification in createClass"
        | RequireDynamicArgument ->
            "The parameter passed to require() must be a literal string."
        | ImportDynamicArgument ->
            "The parameter passed to import() must be a literal string."
        | RequireLazyDynamicArgument ->
            "The first arg to requireLazy() must be a literal array of \
             string literals!"
        | CatchParameterAnnotation ->
            "type annotations for catch params not yet supported"
        | CatchParameterDeclaration ->
            "unsupported catch parameter declaration"
        | DestructuringObjectPropertyLiteralNonString ->
            "unsupported non-string literal object property in destructuring"
        | DestructuringExpressionPattern ->
            "unsupported expression pattern in destructuring"
        | PredicateDeclarationForImplementation ->
            "Cannot declare predicate when a function body is present."
        | PredicateDeclarationWithoutExpression ->
            "Predicate function declarations need to declare a predicate \
             expression."
        | PredicateDeclarationAnonymousParameters ->
            "Predicate function declarations cannot use anonymous function \
             parameters."
        | PredicateInvalidBody ->
            "Invalid body for predicate function. Expected a simple return \
             statement as body."
        | PredicateVoidReturn ->
            "Predicate functions need to return non-void."
        | MultipleIndexers ->
            "multiple indexers are not supported"
        | SpreadArgument ->
            "A spread argument is unsupported here"
      in
      mk_error ~trace_infos [loc, [msg]]

  (* TODO: friendlify *)
  | EIllegalName loc ->
      mk_error ~trace_infos [loc, ["illegal name"]]

  (* TODO: friendlify *)
  | EUseArrayLiteral loc ->
      mk_error ~trace_infos [loc, [
        "Use array literal instead of new Array(..)"
      ]]

  | EMissingAnnotation reason ->
    mk_friendly_error ~trace_infos (loc_of_reason reason)
      [text "Missing type annotation for "; desc reason; text "."]

  (* TODO: friendlify *)
  | EBindingError (binding_error, loc, x, entry) ->
      let msg =
        match binding_error with
        | ENameAlreadyBound ->
            "name is already bound"
        | EReferencedBeforeDeclaration ->
            spf
              "%s referenced before declaration, or after skipped declaration"
              (Scope.Entry.string_of_kind entry)
        | ETypeInValuePosition ->
            "type referenced from value position"
        | ETypeAliasInValuePosition ->
            "type alias referenced from value position"
        | EConstReassigned
        | EConstParamReassigned
        | EImportReassigned ->
            spf "%s cannot be reassigned" (Scope.Entry.string_of_kind entry)
      in
      mk_error ~trace_infos [
        loc, [x; msg];
        Scope.Entry.entry_loc entry, [
          spf "%s %s" (Scope.Entry.string_of_kind entry) x
        ]
      ]

  (* TODO: friendlify *)
  | ERecursionLimit reasons ->
      typecheck_error ~kind:RecursionLimitError "*** Recursion limit exceeded ***" reasons

  (* TODO: friendlify *)
  | EModuleOutsideRoot (loc, package_relative_to_root) ->
      let msg = spf
        "This modules resolves to %S, which is outside both your root \
         directory and all of the entries in the [include] section of your \
         .flowconfig. You should either add this directory to the [include] \
         section of your .flowconfig, move your .flowconfig file higher in \
         the project directory tree, or move this package under your Flow \
         root directory."
        package_relative_to_root
      in
      mk_error ~trace_infos [loc, [msg]]

  (* TODO: friendlify *)
  | EExperimentalDecorators loc ->
      mk_error ~trace_infos ~kind:InferWarning [loc, [
        "Experimental decorator usage";
        "Decorators are an early stage proposal that may change. \
         Additionally, Flow does not account for the type implications \
         of decorators at this time."
      ]]

  (* TODO: friendlify *)
  | EExperimentalClassProperties (loc, static) ->
      let config_name, config_key =
        if static
        then "class static field", "class_static_fields"
        else "class instance field", "class_instance_fields"
      in
      mk_error ~trace_infos ~kind:InferWarning [loc, [
        spf "Experimental %s usage" config_name;
        spf
          "%ss are an active early stage feature proposal that may change. \
           You may opt-in to using them anyway in Flow by putting \
           `esproposal.%s=enable` into the [options] section of your \
           .flowconfig."
          (String.capitalize_ascii config_name)
          config_key
      ]]

  (* TODO: friendlify *)
  | EUnsafeGetSet loc ->
      mk_error ~trace_infos ~kind:InferWarning [loc, [
        "Potentially unsafe get/set usage";
        "Getters and setters with side effects are potentially unsafe and \
         disabled by default. You may opt-in to using them anyway by putting \
         `unsafe.enable_getters_and_setters=true` into the [options] section \
         of your .flowconfig.";
      ]]

  (* TODO: friendlify *)
  | EExperimentalExportStarAs loc ->
      mk_error ~trace_infos ~kind:InferWarning [loc, [
        "Experimental `export * as` usage";
        "`export * as` is an active early stage feature proposal that may \
         change. You may opt-in to using it anyway by putting \
         `esproposal.export_star_as=enable` into the [options] section \
         of your .flowconfig";
      ]]

  (* TODO: friendlify *)
  | EIndeterminateModuleType loc ->
      mk_error ~trace_infos ~kind:InferWarning [loc, [
        "Unable to determine module type (CommonJS vs ES) if both an export \
         statement and module.exports are used in the same module!"
      ]]

  | EUnreachable loc ->
    mk_friendly_error ~trace_infos ~kind:InferWarning loc
      [text "Unreachable code."]

  | EInvalidObjectKit { tool; reason; reason_op; use_op } ->
    let friendly_error =
      unwrap_use_ops_friendly (loc_of_reason reason) use_op
        [ref reason; text " is not an object."]
    in
    (match friendly_error with
    | Some friendly_error -> friendly_error
    | None ->
      let open Object in
      let msg = match tool with
        | ReadOnly -> "Cannot create an object with read-only properties from"
        | Spread _ -> "Cannot spread properties from"
        | Rest (_, state) ->
          let open Object.Rest in
          (match state with
            | One _ -> "Cannot remove properties from"
            | Done _ -> "Cannot remove properties with")
        | ReactConfig state ->
          let open Object.ReactConfig in
          (match state with
            | Config _ -> "Cannot compare React props with"
            | Defaults _ -> "Cannot use React default props from")
      in
      let extra, msgs = unwrap_use_ops ((reason_op, reason), [], msg) use_op in
      typecheck_error_with_core_infos ~extra msgs
    )

  | EInvalidTypeof (loc, typename) ->
    mk_friendly_error ~trace_infos ~kind:InferWarning loc [
      text "Cannot compare the result of "; code "typeof"; text " to string ";
      text "literal "; code typename; text " because it is not a valid ";
      code "typeof"; text " return value.";
    ]

  (* TODO: friendlify *)
  | EArithmeticOperand reason ->
      let msg = "The operand of an arithmetic operation must be a number." in
      mk_error ~trace_infos [mk_info reason [msg]]

  (* TODO: friendlify *)
  | EBinaryInLHS reason ->
      (* TODO: or symbol *)
      let msg =
        "The left-hand side of an `in` expression must be a \
         string or number." in
      mk_error ~trace_infos [mk_info reason [msg]]

  (* TODO: friendlify *)
  | EBinaryInRHS reason ->
      let msg =
        "The right-hand side of an `in` expression must be an \
         object or array." in
      mk_error ~trace_infos [mk_info reason [msg]]

  (* TODO: friendlify *)
  | EForInRHS reason ->
      let msg =
        "The right-hand side of a `for...in` statement must be an \
         object, null or undefined." in
      mk_error ~trace_infos [mk_info reason [msg]]

  (* TODO: friendlify *)
  | EObjectComputedPropertyAccess reasons ->
      typecheck_error "Computed property cannot be accessed with" reasons

  (* TODO: friendlify *)
  | EObjectComputedPropertyAssign reasons ->
      typecheck_error "Computed property cannot be assigned with" reasons

  (* TODO: friendlify *)
  | EInvalidLHSInAssignment loc ->
      let msg = "Invalid left-hand side in assignment expression" in
      mk_error ~trace_infos [loc, [msg]]

  | EIncompatibleWithUseOp (l_reason, u_reason, use_op) ->
    (match (mk_incompatible_friendly_error l_reason u_reason use_op) with
    | Some error -> error
    | None ->
      let ((l_reason, u_reason), use_op) =
        dedupe_by_flip (l_reason, u_reason) use_op in
      let extra, msgs =
        let msg = "This type is incompatible with" in
        unwrap_use_ops ((l_reason, u_reason), [], msg) use_op in
      typecheck_error_with_core_infos ~extra msgs
    )

  | EUnsupportedImplements reason ->
    mk_friendly_error ~trace_infos (loc_of_reason reason)
      [text "Cannot implement "; desc reason; text " because it is not an interface."]

  | EReactKit (reasons, tool, use_op) ->
    let open React in
    let friendly_error =
      let (_, reason) = reasons in
      let is_not_prop_type = "is not a React propType" in
      let msg = match tool with
      | GetProps _
      | GetConfig _
      | GetRef _
      | CreateElement _
        -> "is not a React component"
      | SimplifyPropType (tool, _) ->
        SimplifyPropType.(match tool with
        | ArrayOf -> is_not_prop_type
        | InstanceOf -> "is not a class"
        | ObjectOf -> is_not_prop_type
        | OneOf ResolveArray -> "is not an array"
        | OneOf (ResolveElem _) -> "is not a literal"
        | OneOfType ResolveArray -> "is not an array"
        | OneOfType (ResolveElem _) -> is_not_prop_type
        | Shape ResolveObject -> "is not an object"
        | Shape (ResolveDict _) -> is_not_prop_type
        | Shape (ResolveProp _) -> is_not_prop_type
        )
      | CreateClass (tool, _, _) ->
        CreateClass.(match tool with
        | Spec _ -> "is not an exact object"
        | Mixins _ -> "is not a tuple"
        | Statics _ -> "is not an object"
        | PropTypes (_, ResolveObject) -> "is not an object"
        | PropTypes (_, ResolveDict _) -> is_not_prop_type
        | PropTypes (_, ResolveProp _) -> is_not_prop_type
        | DefaultProps _ -> "is not an object"
        | InitialState _ -> "is not an object or null"
        )
      in
      unwrap_use_ops_friendly (loc_of_reason reason) use_op
        [ref reason; text (" " ^ msg ^ ".")]
    in
    (match friendly_error with
    | Some friendly_error -> friendly_error
    | None ->
      let expected_prop_type = "Expected a React PropType instead of" in
      let resolve_object prop = function
      | ResolveObject -> "Expected an object instead of"
      | ResolveDict _ -> prop
      | ResolveProp _ -> prop
      in
      let resolve_array elem = function
      | ResolveArray -> "Expected an array instead of"
      | ResolveElem _ -> elem
      in
      let simplify_prop_type = SimplifyPropType.(function
      | ArrayOf -> expected_prop_type
      | InstanceOf -> "Expected a class type instead of"
      | ObjectOf -> expected_prop_type
      | OneOf tool -> resolve_array "Expected a literal type instead of" tool
      | OneOfType tool -> resolve_array expected_prop_type tool
      | Shape tool -> resolve_object expected_prop_type tool
      ) in
      let create_class = CreateClass.(function
      | Spec _ ->
        "Expected an exact object instead of"
      | Mixins _ ->
        "`mixins` should be a tuple instead of"
      | Statics _ ->
        "`statics` should be an object instead of"
      | PropTypes (_, tool) ->
        resolve_object expected_prop_type tool
      | DefaultProps _ ->
        "`defaultProps` should be an object instead of"
      | InitialState _ ->
        "`initialState` should be an object or null instead of"
      ) in
      let msg = match tool with
      | SimplifyPropType (tool, _) -> simplify_prop_type tool
      | GetProps _ -> "Expected React component instead of"
      | GetConfig _ -> "Expected React component instead of"
      | GetRef _ -> "Expected React component instead of"
      | CreateClass (tool, _, _) -> create_class tool
      | CreateElement _ -> "Expected React component instead of"
      in
      let extra, msgs = unwrap_use_ops (reasons, [], msg) use_op in
      typecheck_error_with_core_infos ~extra msgs
    )

  (* TODO: friendlify *)
  | EReactElementFunArity (reason, fn, n) ->
      mk_error ~trace_infos [mk_info reason [
        "React." ^ fn ^ "() must be passed at least " ^ (string_of_int n) ^ " arguments."
      ]]

  | EFunctionCallExtraArg (unused_reason, def_reason, param_count, use_op) ->
    let friendly_error =
      let msg = match param_count with
      | 0 -> "no arguments are expected by"
      | 1 -> "no more than 1 argument is expected by"
      | n -> spf "no more than %d arguments are expected by" n
      in
      unwrap_use_ops_friendly (loc_of_reason unused_reason) use_op
        [text msg; text " "; ref def_reason; text "."]
    in
    (match friendly_error with
    | Some friendly_error -> friendly_error
    | None ->
      let msg = match param_count with
      | 0 -> "No arguments are expected by"
      | 1 -> "No more than 1 argument is expected by"
      | n -> spf "No more than %d arguments are expected by" n
      in
      let extra, msgs = unwrap_use_ops ((unused_reason, def_reason), [], msg) use_op in
      typecheck_error_with_core_infos ~extra msgs
    )

  (* TODO: friendlify *)
  | EUnsupportedSetProto reason ->
      mk_error ~trace_infos [mk_info reason [
        "Prototype mutation not allowed"]]

  (* TODO: friendlify *)
  | EDuplicateModuleProvider {module_name; provider; conflict} ->
      mk_error ~kind:DuplicateProviderError [
        Loc.({ none with source = Some conflict }), [
          module_name; "Duplicate module provider"];
        Loc.({ none with source = Some provider }), [
          "current provider"]
      ]

  (* TODO: friendlify *)
  | EParseError (loc, parse_error) ->
    mk_error ~kind:ParseError [loc, [Parse_error.PP.error parse_error]]

  (* TODO: friendlify *)
  | EDocblockError (loc, err) ->
    let msg = match err with
    | MultipleFlowAttributes ->
      "Unexpected @flow declaration. Only one per file is allowed."
    | MultipleProvidesModuleAttributes ->
      "Unexpected @providesModule declaration. Only one per file is allowed."
    | MultipleJSXAttributes ->
      "Unexpected @jsx declaration. Only one per file is allowed."
    | InvalidJSXAttribute first_error ->
      "Invalid @jsx declaration. Should have form `@jsx LeftHandSideExpression` "^
      "with no spaces."^
      (match first_error with
      | None -> ""
      | Some first_error -> spf " Parse error: %s" first_error)
    in
    mk_error ~kind:ParseError [loc, [msg]]

  (* TODO: friendlify *)
  | EUntypedTypeImport (loc, module_name) ->
    mk_error
      ~kind:(LintError Lints.UntypedTypeImport)
      [loc, [spf (
        "Importing a type from an untyped module makes it `any` and is not safe! "^^
        "Did you mean to add `// @flow` to the top of `%s`?"
      ) module_name]]

  (* TODO: friendlify *)
  | EUntypedImport (loc, module_name) ->
    mk_error
      ~kind:(LintError Lints.UntypedImport)
      [loc, [spf (
        "Importing from an untyped module makes it `any` and is not safe! "^^
        "Did you mean to add `// @flow` to the top of `%s`?"
      ) module_name]]

  (* TODO: friendlify *)
  | ENonstrictImport loc ->
    mk_error
      ~kind:(LintError Lints.NonstrictImport)
      [loc, ["Dependencies of a `@flow strict` module must also be `@flow strict`"]]

  (* TODO: friendlify *)
  | EUnclearType loc ->
    mk_error
      ~kind:(LintError Lints.UnclearType)
      [loc, ["Unclear type. Using `any`, `Object` or `Function` types is not safe!"]]

  (* TODO: friendlify *)
  | EUnsafeGettersSetters loc ->
    mk_error
      ~kind:(LintError Lints.UnsafeGettersSetters)
      [loc, ["Getters and Setters can have side effects and are unsafe"]]

  (* TODO: friendlify *)
  | EDeprecatedDeclareExports loc ->
    mk_error
      ~kind:(LintError Lints.DeprecatedDeclareExports)
      [loc, ["Deprecated syntax. Use `declare module.exports` instead."]]

  (* TODO: friendlify *)
  | EUnusedSuppression loc ->
    mk_error [loc, ["Error suppressing comment"; "Unused suppression"]]

  (* TODO: friendlify *)
  | ELintSetting (loc, kind) ->
    let msg = match kind with
    | LintSettings.Redundant_argument ->
      "Redundant argument. This argument doesn't change any lint settings."
    | LintSettings.Overwritten_argument ->
      "Redundant argument. "
        ^ "The values set by this argument are overwritten later in this comment."
    | LintSettings.Naked_comment ->
      "Malformed lint rule. At least one argument is required."
    | LintSettings.Nonexistent_rule ->
      "Nonexistent/misspelled lint rule. Perhaps you have a missing/extra ','?"
    | LintSettings.Invalid_setting ->
      "Invalid setting. Valid settings are error, warn, and off."
    | LintSettings.Malformed_argument ->
      "Malformed lint rule. Properly formed rules contain a single ':' character. " ^
        "Perhaps you have a missing/extra ','?"
    in
    mk_error ~kind: ParseError [loc, [msg]]

  (* TODO: friendlify *)
  | ESketchyNullLint { kind; loc; null_loc; falsy_loc } ->
    let type_str, value_str = match kind with
    | Lints.SketchyBool -> "boolean", "Potentially false"
    | Lints.SketchyNumber -> "number", "Potentially 0"
    | Lints.SketchyString -> "string", "Potentially \"\""
    | Lints.SketchyMixed -> "mixed", "Mixed"
    in
    mk_error
      ~kind:(LintError (Lints.SketchyNull kind))
      [loc, [(spf "Sketchy null check on %s value." type_str)
        ^ " Perhaps you meant to check for null instead of for existence?"]]
      ~extra:[InfoLeaf [
        null_loc, ["Potentially null/undefined value."];
        falsy_loc, [spf "%s value." value_str]
      ]]

  (* TODO: friendlify *)
  | EInvalidPrototype reason ->
      mk_error ~trace_infos [mk_info reason [
        "Invalid prototype. Expected an object or null."]]
