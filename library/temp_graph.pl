:- module(temp_graph,[
              extend_database_with_temp_graph/6
          ]).

/** <module> Temp Graph
 *
 * Create a temporary graph from one of the recognised file formats, with an
 * implicit ontology. This can then be queried repeatedly.
 *
 * * * * * * * * * * * * * COPYRIGHT NOTICE  * * * * * * * * * * * * * * *
 *                                                                       *
 *  This file is part of TerminusDB.                                     *
 *                                                                       *
 *  TerminusDB is free software: you can redistribute it and/or modify   *
 *  it under the terms of the GNU General Public License as published by *
 *  the Free Software Foundation, under version 3 of the License.        *
 *                                                                       *
 *                                                                       *
 *  TerminusDB is distributed in the hope that it will be useful,        *
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of       *
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        *
 *  GNU General Public License for more details.                         *
 *                                                                       *
 *  You should have received a copy of the GNU General Public License    *
 *  along with TerminusDB.  If not, see <https://www.gnu.org/licenses/>. *
 *                                                                       *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

:- use_module(triplestore).
:- use_module(database).
:- use_module(library(semweb/turtle)).
:- use_module(literals).

/*
 * extend_database_with_temp_graph(+Graph_Name, +Path, +Options, -Program,
 *                                 ?Old_Database, ?Database) is det.
 *
 * Currently only respects rdf!
 */
extend_database_with_temp_graph(Graph_Name, Path, Options, Program, Old_Database, Database) :-

    Program = (
        (   triplestore:open_memory_store(Store),
            triplestore:open_write(Store, Builder),
            open(Path, read, Stream, []),
            turtle:rdf_process_turtle(
                Stream,
                {Builder}/
                [Triples,_Resource]>>(
                    forall(member(T, Triples),
                           (   literals:normalise_triple(T, rdf(X,P,Y)),
                               literals:object_storage(Y,S),
                               triplestore:nb_add_triple(Builder, X, P, S)
                           ))),
                [encoding(utf8)]),
            % commit this builder to a temporary layer to perform a diff.
            triplestore:nb_commit(Builder,Layer)
        ->  true
        ;   format(atom(M), 'Unable to load graph ~q from path ~q with options ~q',
                   [Graph_Name, Path, Options]),
            throw(error(M))
        )
    ),

    Old_Database.name = N,
    Old_Database.read_transaction = RTs,
    Old_Database.write_transaction = WTs,
    New_RTs = [read_obj{dbid : N,
                        graphid : Graph_Name,
                        layer : Layer}
               | RTs],
    Database = Old_Database.put( database{read_transaction: New_RTs,
                                          write_transaction: WTs }).
