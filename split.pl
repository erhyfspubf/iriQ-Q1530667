% split a monolithic model fragment into modular fragments so as to obtain a minimized model
% input: a flat list of dependencies (as generated by eg. model induction or
% 	from a monolithic model fragment created by a user).  
% background: entity hierarchy, quantities of each entity
% output: a minimized model containing multiple model fragments

go  :- do(treeshade).
go1 :- do(bathtub).
go2 :- do(comves).
go3 :- do(comves3).

do(File) :-
	consult(File),
	% monolithic model
	model(M),
	write('Input: '), nl, write(M), nl, nl,
	split(M, MF),
	write(MF).


% SCENARIO

/*
%engine:isa
entity(A, B) :-
	isa_transitive(B, A).

%TODO
has_quantity(A, B) :-
	get_quantity_entity_types([B], EntityTypes),
	member(A,  EntityTypes).
	%input.pl:65 ongeveer

struct_rel(R, A, B) :-
	.
*/


%todo: automate etc. atom_concat etc.

% given a flat list of dependencies, make a partition corresponding to
% dependencies related by the same condition.  then generalize the parts of
% these partitions, returning a minimized model.  this output can be converted
% into Garp model fragments
split(M, MF) :-
	%fragments(M, SF),
	SF = [],
	combined_pivots(M, SF, CF),
	append(SF, CF, F), 
	unfragment(M, F, UF),
	length(SF, N), length(CF, N1),
	write('Single Fragments ('), write(N), write('): '), nl,
	forall(member(Fr, SF), (write(Fr), nl)), nl,
	write('Poly Fragments ('), write(N1), write('): '), nl,
	forall(member(Frr, CF), (write(Frr), nl)), nl,
	write('Unfragments: '), write(UF), nl, nl,
	append(F, UF, MF).

% find an instance of a structural relation and two entity classes using
% a relation between instances
instance(R, E1, E2) :-
	struct_rel(R, EI1, EI2),
	isa(EI1, E1), isa(EI2, E2).

% find an instance of a structural relation and two quantities belonging to
% their entities
qinstance(R, E1, E2, QI1, QI2, Q1, Q2) :-
	isa(EI1, E1), isa(EI2, E2),
	struct_rel(R, EI1, EI2),
	has_quantity(EI1,QI1),
	has_quantity(EI2,QI2),
	isa(QI1, Q1), isa(QI2, Q2).

% check whether all instances of a triple of a structural relation and 
% two entity classes share the same dependencies
same_deps(R, E1, E2, M) :-
	qinstance(R, E1, E2, QI1, QI2, Q1, Q2),
	forall(	
		qinstance(R, E1, E2, QJ1, QJ2, Q1, Q2),
		(	forall(
				member(dependency(D, QI1, QI2), M),
				member(dependency(D, QJ1, QJ2), M)
			),
			forall(
				member(dependency(D, QI2, QI1), M),
				member(dependency(D, QJ2, QJ1), M)
			)
		)
	).

pivots(M, P) :-
	findall( (R, E1, E2),
		(	instance(R, E1, E2),
			same_deps(R, E1, E2, M)
		),
		Rels1
	), 
	findall( (R, E1, E2),
		(	member( (R, E1, E2), Rels1),
			(R = self ->
				E1 @=< E2
			; 	true)
		),
		Rels),
	list_to_set(Rels, P).

% fragments that can be generalized (ie., relations between quantity classes)
% collapes M into a set of sets containing generalized dependencies.
%
% incorrect definition (todo): fragments = smallest union of all possible sets
% { d | dependency(d) & d = generalized(di) & di in M } such that there is
% exactly one structural relation shared by them.
%
% where dependency is true for dependency triples, and generalized is a
% function that takes a dependency between instances of quantities and returns
% a dependency between the classes of those entities.
fragments(M, F) :-
	pivots(M, Rels),
	write('Set of struct rels: '), write(Rels), nl,
	%generalize arguments of dependencies from instances to generic quantities
	findall([ (R, E1, E2) | Deps ],
		(	member( (R, E1, E2), Rels),
			genall(M, (R, E1, E2), Deps1), 
			list_to_set(Deps1, Deps),
			\+ Deps = []
		),
		F
	).

first([H], H).
first([H|_], H).
	
%take a dependency between instances and return a generic dependency
generalize(DepI, Dep, _Pivot) :-
	DepI = dependency(D, QI1, QI2),
	generalize_quantity(QI1, Q1),
	generalize_quantity(QI2, Q2),
	Dep = dependency(D, Q1, Q2).

generalize_quantity(QI, Q) :-
	isa(QI, Q).

% hack to support min: write more general code
generalize_quantity(min(QI1, QI2), min(Q1, Q2)) :-
	generalize_quantity(QI1, Q1),
	generalize_quantity(QI2, Q2).

genall(DepsI, Pivot, Deps) :-
	findall(Dep,
		(	member(DepI, DepsI),
			%fixme: qinstance(R1, E1, E2, QI1, QI2, Q1, Q2),
			generalize(DepI, Dep, Pivot)
		),
		Deps).

%try to formulate fragments for dependencies by looking
%for pivots using a bottom-up strategy
combined_pivots(M, F, CF) :-
	% fetch not yet generalized dependencies
	findall(dependency(D, QI1, QI2), 
		(	member(dependency(D, QI1, QI2), M), 
			\+ (	member(Fr, F), 
				isa(QI1, Q1), isa(QI2, Q2), 
				memberchk(dependency(D, Q1, Q2), Fr))),
		Rest),
	% find all pivot paths in a bottom up fashion
	findall( [Pivot, DepI],
		(	member(DepI, Rest),
			deprels(DepI, Pivot)
		),
		Deps),
	% group pivot-dep pairs into [pivot|deps] lists
	groupby(Deps, GDeps),
	% samedeps check for n-pivots:	TBD.
	% generalize deps
	findall([ Pivot | DepsSet ],
		(	member( [ Pivot | DepsI ], GDeps),
			genall(DepsI, Pivot, GenDeps),
			list_to_set(GenDeps, DepsSet)
		),
		CF).

%given a list of dependencies, yield a path of relations leading
%from one to the other entity
deprels(dependency(_, QI1, QI2), Pivot) :-
	has_quantity(EI1, QI1), 
	has_quantity(EI2, QI2),
	rels(EI1, EI2, [], Pivot).

% hack to support min: write more general code
deprels(dependency(_, _QI1, min(QI2A, QI2B)), Pivot) :-
	has_quantity(EI1, QI2A), 
	has_quantity(EI2, QI2B),
	rels(EI1, EI2, [], Pivot).

rels(EI1, EI2, _, [ (R, E1, E2) ]) :-
	struct_rel(R, EI1, EI2),
	isa(EI1, E1), isa(EI2, E2), !.

rels(EI1, EI2, _, [ (R, E2, E1) ]) :-
	struct_rel(R, EI2, EI1),
	isa(EI1, E1), isa(EI2, E2), !.

%transitive relations
rels(EI1, EI3, Stack, [ (R, E1, E2) | PivotRest ]) :-
	struct_rel(R, EI1, EI2),
	\+ R = self, \+ member((R, E1, E2), Stack),
	isa(EI1, E1), isa(EI2, E2), 
	rels(EI2, EI3, [ (R, E1, E2) | Stack ], PivotRest).

rels(EI1, EI3, Stack, [ (R, E2, E1) | PivotRest ]) :-
	struct_rel(R, EI2, EI1), 
	\+ R = self, \+ member((R, E2, E1), Stack),
	isa(EI1, E1), isa(EI2, E2), 
	rels(EI2, EI3, [ (R, E2, E1) | Stack ], PivotRest).
	
% turn list of key-value pairs into list of lists where the head is the key.
% ie., [ [a, b], [a, c], [b, d] ] -> [ [a, b, c], [b, d] ]
groupby(In, Out) :-
	findall([P | Deps],
		aggregate(bag(X), 
			member([P, X], In), 
			Deps),
		Out).

% unfragment: all dependencies that cannot be generalized; ie., relations
% between specific quantities, would need further conditions to generalize, 
% here we give up and specify them using particular quantity names).
%
% definition: unfragments = { d | dependency(d) & not exists f in Fragments s.t. generalized(d) in f }
unfragment(M, F, UF) :-
	findall(DepI,
		(	member(DepI, M), 
			\+ (	member(Fr, F), 
				generalize(DepI, Dep, _),
				memberchk(Dep, Fr))),
		UF).
